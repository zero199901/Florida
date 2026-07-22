import sys
from pathlib import Path


def log_color(msg):
    print(f"\033[1;31;40m{msg}\033[0m")


if __name__ == "__main__":
    input_file = Path(sys.argv[1])
    log_color(f"[*] Leave embedded agent runtime intact: {input_file}")
    # Stability-first Android 16 profile: resource filenames and server ports are
    # changed elsewhere; keep Gum/Java bridge binary contents untouched.
    log_color("[*] Patch Finish")
