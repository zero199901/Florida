#!/usr/bin/env python3
"""
扫描目录或文件中的 Frida 相关特征串。

特点：
- 直接扫描原始字节，不依赖外部 strings 命令
- 自动支持 .gz / .xz / 原始文件
- 可输出文本或 JSON
"""

from __future__ import annotations

import argparse
import gzip
import json
import lzma
from pathlib import Path


CORE_RULES = [
    "FridaScriptEngine",
    "GLib-GIO",
    "GDBusProxy",
    "GumScript",
    "gum-js-loop",
    "gmain",
    "gdbus",
]

STRICT_RULES = [
    "frida:rpc",
    "re.frida",
    "frida-helper",
    "frida-gadget",
    "frida-server",
    "frida-inject",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="扫描 Frida 特征串")
    parser.add_argument("paths", nargs="+", help="待扫描的文件或目录")
    parser.add_argument(
        "--rules",
        choices=["core", "strict"],
        default="core",
        help="使用内置规则组",
    )
    parser.add_argument(
        "--needle",
        action="append",
        default=[],
        help="额外追加自定义关键字，可重复传入",
    )
    parser.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="输出格式",
    )
    parser.add_argument(
        "--context",
        type=int,
        default=24,
        help="命中点前后显示的上下文字节数",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=10,
        help="每个关键字每个文件最多输出多少条命中",
    )
    return parser.parse_args()


def expand_paths(inputs: list[str]) -> list[Path]:
    files: list[Path] = []
    for item in inputs:
        path = Path(item)
        if path.is_file():
            files.append(path)
            continue
        if path.is_dir():
            for child in sorted(p for p in path.rglob("*") if p.is_file()):
                files.append(child)
    return files


def read_bytes(path: Path) -> bytes:
    suffixes = path.suffixes
    if suffixes and suffixes[-1] == ".gz":
        with gzip.open(path, "rb") as handle:
            return handle.read()
    if suffixes and suffixes[-1] == ".xz":
        with lzma.open(path, "rb") as handle:
            return handle.read()
    return path.read_bytes()


def iter_hits(data: bytes, needle: bytes, limit: int) -> list[int]:
    hits: list[int] = []
    start = 0
    while len(hits) < limit:
        idx = data.find(needle, start)
        if idx == -1:
            break
        hits.append(idx)
        start = idx + 1
    return hits


def make_context(data: bytes, offset: int, length: int, radius: int) -> str:
    begin = max(0, offset - radius)
    end = min(len(data), offset + length + radius)
    chunk = data[begin:end]
    return "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)


def scan_file(path: Path, rules: list[str], context: int, limit: int) -> dict:
    result = {
        "path": str(path),
        "size": 0,
        "matches": [],
        "error": None,
    }
    try:
        data = read_bytes(path)
        result["size"] = len(data)
        for rule in rules:
            needle = rule.encode("utf-8")
            offsets = iter_hits(data, needle, limit)
            for offset in offsets:
                result["matches"].append(
                    {
                        "keyword": rule,
                        "offset": offset,
                        "context": make_context(data, offset, len(needle), context),
                    }
                )
    except Exception as exc:  # pragma: no cover - CLI fallback
        result["error"] = str(exc)
    return result


def render_text(results: list[dict]) -> int:
    total = 0
    for item in results:
        if item["error"] is not None:
            print(f"{item['path']}: ERROR {item['error']}")
            continue
        if not item["matches"]:
            continue
        print(f"\n{item['path']}")
        print(f"  size={item['size']}")
        for match in item["matches"]:
            total += 1
            print(
                f"  - {match['keyword']} @ 0x{match['offset']:x}: "
                f"{match['context']}"
            )
    return total


def main() -> int:
    args = parse_args()
    rules = list(CORE_RULES)
    if args.rules == "strict":
        rules.extend(STRICT_RULES)
    for extra in args.needle:
        if extra not in rules:
            rules.append(extra)

    files = expand_paths(args.paths)
    if not files:
        print("未找到可扫描文件")
        return 1

    results = [scan_file(path, rules, args.context, args.limit) for path in files]

    if args.format == "json":
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return 0

    total = render_text(results)
    if total == 0:
        print("未命中特征串")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
