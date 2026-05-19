#!/usr/bin/env python3
"""
验证 Florida release-assets 里的产物是否完成关键 patch。
"""

from __future__ import annotations

import argparse
import gzip
import lzma
from pathlib import Path


BAD_STRINGS = [
    "FridaScriptEngine",
    "GLib-GIO",
    "GDBusProxy",
    "GumScript",
    "gum-js-loop",
    "gmain",
    "gdbus",
]

STRICT_BAD_STRINGS = [
    "frida:rpc",
    "re.frida",
    "frida-helper",
]

GOOD_STRINGS = [
    "enignEtpircSadirF",
    "OIG-biLG",
    "yxorPsuBDG",
    "tpircSmuG",
]

ARTIFACT_PATTERNS = [
    "florida-server-*-android-*.gz",
    "florida-inject-*-android-*.gz",
    "florida-gadget-*-android-*.so.gz",
    "florida-gumjs-*-android-*.a.gz",
]


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
        help="开启严格模式，额外检查 frida:rpc / re.frida / frida-helper",
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


def verify_one(path: Path, strict: bool, require_good: bool) -> tuple[bool, list[str], list[str], list[str]]:
    data = read_bytes(path)
    found_bad = contains_any(data, BAD_STRINGS)
    found_good = contains_any(data, GOOD_STRINGS)
    found_strict = contains_any(data, STRICT_BAD_STRINGS) if strict else []

    is_gumjs = "-gumjs-" in path.name
    missing_good = require_good and not is_gumjs and not found_good

    passed = not found_bad and not found_strict and not missing_good
    if missing_good:
        found_bad = found_bad + ["<missing patched marker>"]

    return passed, found_bad, found_good, found_strict


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
            passed, found_bad, found_good, found_strict = verify_one(
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
        if found_good:
            print(f"  已 patch 标记: {', '.join(found_good)}")
        if not found_bad and not found_strict and not found_good:
            print("  说明: 未发现坏特征串")

    print("\n" + "=" * 70)
    print("全部通过" if all_passed else "存在未 patch 产物")
    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
