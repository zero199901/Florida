#!/usr/bin/env python3
"""
验证 Florida release-assets 里的产物是否完成关键 patch。
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import lzma
from pathlib import Path
import zlib


BAD_STRINGS = [
    "FridaScriptEngine",
    "GLib-GIO",
    "GDBusProxy",
    "GumScript",
    "gum-js-loop",
    "gmain",
    "gdbus",
    "frida-zymbiote",
    "frida-error-quark",
]

STRICT_BAD_STRINGS = [
    "frida:rpc",
    "re.frida",
    "re/frida",
    "frida-helper",
    "frida-agent",
    "FridaLinjector",
    "Linjector",
    "linjector",
    "frida-eternal-agent",
    "frida-agent-emulated",
    "frida-generate-certificate",
    "frida-gadget-tcp-",
    "frida-gadget-unix",
    "frida-agent-container",
    "frida-android-helper",
]

GOOD_STRINGS = [
    "enignEtpircSadirF",
    "OIG-biLG",
    "yxorPsuBDG",
    "tpircSmuG",
]

WARN_STRINGS = [
    "frida-server",
    "frida-gadget",
]

INFO_STRINGS = [
    "/frida-",
]

ARTIFACT_PATTERNS = [
    "florida-server-*-android-*.gz",
    "florida-inject-*-android-*.gz",
    "florida-gadget-*-android-*.so.gz",
    "florida-gumjs-*-android-*.a.gz",
]

DEX_MAGIC_PREFIX = b"dex\n"
DEX_HEADER_SIZE = 0x70


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="验证 Florida 产物 patch 状态")
    parser.add_argument(
        "target",
        nargs="?",
        default="release-assets",
        help="待检查目录，默认 release-assets",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="开启严格模式，额外检查 rpc / helper / agent / injector 残留",
    )
    parser.add_argument(
        "--require-good",
        action="store_true",
        help="要求非 gumjs 产物至少命中一个已 patch 特征串",
    )
    return parser.parse_args()


def read_bytes(path: Path) -> bytes:
    suffixes = path.suffixes
    if suffixes and suffixes[-1] == ".gz":
        with gzip.open(path, "rb") as handle:
            return handle.read()
    if suffixes and suffixes[-1] == ".xz":
        with lzma.open(path, "rb") as handle:
            return handle.read()
    return path.read_bytes()


def find_artifacts(root: Path) -> list[Path]:
    artifacts: list[Path] = []
    for pattern in ARTIFACT_PATTERNS:
        artifacts.extend(root.glob(pattern))
    return sorted(set(path for path in artifacts if path.is_file()))


def contains_any(data: bytes, needles: list[str]) -> list[str]:
    found: list[str] = []
    for needle in needles:
        if needle.encode("utf-8") in data:
            found.append(needle)
    return found


def find_broken_embedded_dex(data: bytes) -> list[str]:
    broken: list[str] = []
    start = 0
    while True:
        offset = data.find(DEX_MAGIC_PREFIX, start)
        if offset == -1:
            break
        if offset + DEX_HEADER_SIZE > len(data):
            break

        version = data[offset + 4:offset + 7]
        file_size = int.from_bytes(data[offset + 0x20:offset + 0x24], "little")
        header_size = int.from_bytes(data[offset + 0x24:offset + 0x28], "little")
        endian_tag = int.from_bytes(data[offset + 0x28:offset + 0x2C], "little")
        is_dex = (
            data[offset + 7] == 0
            and version.isdigit()
            and header_size == DEX_HEADER_SIZE
            and file_size >= DEX_HEADER_SIZE
            and offset + file_size <= len(data)
            and endian_tag in {0x12345678, 0x78563412}
        )
        if not is_dex:
            start = offset + 4
            continue

        dex = data[offset:offset + file_size]
        expected_checksum = int.from_bytes(dex[8:12], "little")
        actual_checksum = zlib.adler32(dex[12:]) & 0xFFFFFFFF
        expected_signature = dex[12:32].hex()
        actual_signature = hashlib.sha1(dex[32:]).hexdigest()
        if expected_checksum != actual_checksum or expected_signature != actual_signature:
            broken.append(
                f"@0x{offset:x} size={file_size} "
                f"adler={expected_checksum:08x}/{actual_checksum:08x} "
                f"sha1={expected_signature[:8]}.../{actual_signature[:8]}..."
            )
        start = offset + file_size

    return broken


def is_gumjs_static_archive(path: Path) -> bool:
    return "-gumjs-" in path.name and ".a." in path.name


def verify_one(
    path: Path,
    strict: bool,
    require_good: bool,
) -> tuple[bool, list[str], list[str], list[str], list[str], list[str], list[str], list[str]]:
    data = read_bytes(path)
    found_bad = contains_any(data, BAD_STRINGS)
    found_good = contains_any(data, GOOD_STRINGS)
    found_strict = contains_any(data, STRICT_BAD_STRINGS) if strict else []
    found_warn = contains_any(data, WARN_STRINGS)
    found_info = contains_any(data, INFO_STRINGS)
    broken_dex = find_broken_embedded_dex(data)
    ignored_bad: list[str] = []

    is_gumjs = is_gumjs_static_archive(path)
    missing_good = require_good and not is_gumjs and not found_good

    passed = not found_bad and not found_strict and not missing_good and not broken_dex
    if missing_good:
        found_bad = found_bad + ["<missing patched marker>"]

    return (
        passed,
        found_bad,
        found_good,
        found_strict,
        found_warn,
        found_info,
        broken_dex,
        ignored_bad,
    )


def main() -> int:
    args = parse_args()
    root = Path(args.target)
    if not root.exists():
        print(f"目录不存在: {root}")
        return 1

    artifacts = find_artifacts(root)
    if not artifacts:
        print(f"未找到 Florida 产物: {root}")
        return 1

    print("=" * 70)
    print("Florida patch 验证")
    print("=" * 70)
    print(f"目录: {root}")
    print(f"产物数: {len(artifacts)}")
    if args.strict:
        print("模式: strict")
    if args.require_good:
        print("额外要求: 非 gumjs 产物必须命中至少一个已 patch 标记")
    print("-" * 70)

    all_passed = True
    for artifact in artifacts:
        try:
            (
                passed,
                found_bad,
                found_good,
                found_strict,
                found_warn,
                found_info,
                broken_dex,
                ignored_bad,
            ) = verify_one(
                artifact,
                args.strict,
                args.require_good,
            )
        except Exception as exc:  # pragma: no cover - CLI fallback
            all_passed = False
            print(f"\n{artifact.name}\n  状态: FAIL\n  错误: {exc}")
            continue

        all_passed = all_passed and passed
        print(f"\n{artifact.name}")
        print(f"  状态: {'PASS' if passed else 'FAIL'}")
        if found_bad:
            print(f"  未 patch: {', '.join(found_bad)}")
        if found_strict:
            print(f"  严格检查命中: {', '.join(found_strict)}")
        if found_warn:
            print(f"  WARN: {', '.join(found_warn)}")
        if found_info:
            print(f"  INFO: {', '.join(found_info)}")
        if broken_dex:
            print(f"  嵌入 dex 校验失败: {'; '.join(broken_dex)}")
        if ignored_bad:
            print(f"  静态库保留符号(仅提示): {', '.join(ignored_bad)}")
        if found_good:
            print(f"  已 patch 标记: {', '.join(found_good)}")
        if (
            not found_bad
            and not found_strict
            and not found_warn
            and not found_info
            and not broken_dex
            and not found_good
            and not ignored_bad
        ):
            print("  说明: 未发现坏特征串")

    print("\n" + "=" * 70)
    print("全部通过" if all_passed else "存在未 patch 产物")
    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
