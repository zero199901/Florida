#!/usr/bin/env python3
"""
Florida 构建后统一后处理入口。

作用：
- 统一调度 patched frida-core 里的 anti-anti-frida.py
- 对 shared-library / executable 类型产物执行 patch
- 默认用于 Linux / Android 产物
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


PATCHABLE_KINDS = {"shared-library", "executable"}
PATCHABLE_HOSTS = {"android", "linux"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Florida 统一后处理入口")
    parser.add_argument(
        "artifacts",
        nargs="+",
        help="待处理产物路径，可传多个",
    )
    parser.add_argument(
        "--kind",
        choices=["shared-library", "executable", "static-library"],
        default="executable",
        help="产物类型",
    )
    parser.add_argument(
        "--host-os",
        default="android",
        help="目标系统，默认 android",
    )
    parser.add_argument(
        "--source-root",
        default="frida/subprojects/frida-core",
        help="patched frida-core 根目录",
    )
    parser.add_argument(
        "--patch-script",
        help="显式指定 anti-anti-frida.py 路径",
    )
    return parser.parse_args()


def resolve_patch_script(args: argparse.Namespace) -> Path:
    if args.patch_script:
        return Path(args.patch_script)
    return Path(args.source_root) / "src" / "anti-anti-frida.py"


def should_patch(kind: str, host_os: str) -> bool:
    return kind in PATCHABLE_KINDS and host_os in PATCHABLE_HOSTS


def patch_one(script: Path, artifact: Path) -> int:
    command = [sys.executable, str(script), str(artifact)]
    completed = subprocess.run(command, check=False)
    return completed.returncode


def main() -> int:
    args = parse_args()
    patch_script = resolve_patch_script(args)
    if not patch_script.exists():
        print(f"patch 脚本不存在: {patch_script}")
        return 1

    if not should_patch(args.kind, args.host_os):
        print(
            f"跳过后处理: kind={args.kind} host_os={args.host_os} "
            f"不在启用列表中"
        )
        return 0

    for artifact_arg in args.artifacts:
        artifact = Path(artifact_arg)
        if not artifact.exists():
            print(f"产物不存在: {artifact}")
            return 1
        print(f"[Florida] post-process {artifact}")
        code = patch_one(patch_script, artifact)
        if code != 0:
            print(f"[Florida] post-process FAIL: {artifact} exit={code}")
            return code
        print(f"[Florida] post-process OK: {artifact}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
