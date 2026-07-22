import lief
import sys
import random
import string
from pathlib import Path


def log_color(msg):
    print(f"\033[1;31;40m{msg}\033[0m")


def make_token(length):
    return "".join(random.choice(string.ascii_letters) for _ in range(length))


def make_replacement(marker, replacement=None):
    marker_bytes = marker.encode()
    if replacement is None:
        replacement = make_token(len(marker_bytes))
    replacement_bytes = replacement.encode()
    if len(replacement_bytes) > len(marker_bytes):
        raise ValueError(f"replacement too long for {marker}: {replacement}")
    return replacement_bytes + (b"\x00" * (len(marker_bytes) - len(replacement_bytes)))


def patch_bytes(path, replacements):
    data = path.read_bytes()
    patched = data
    total = 0

    for marker, replacement in replacements:
        marker_bytes = marker.encode()
        replacement_bytes = make_replacement(marker, replacement)
        count = patched.count(marker_bytes)
        if count == 0:
            continue
        patched = patched.replace(marker_bytes, replacement_bytes)
        total += count
        display = replacement if replacement is not None else replacement_bytes.rstrip(b"\x00").decode(errors="ignore")
        log_color(f"[*] Patch `{marker}` -> `{display}` count={count}")

    if patched != data:
        path.write_bytes(patched)

    return total


if __name__ == "__main__":
    input_file = Path(sys.argv[1])
    log_color(f"[*] Patch frida-agent: {input_file}")
    binary = lief.parse(input_file)

    if not binary:
        log_color("[*] Not elf, exit")
        exit()

    random_name = make_token(5)
    log_color(f"[*] Patch `frida` to `{random_name}`")

    for symbol in binary.symbols:
        if symbol.name == "frida_agent_main":
            symbol.name = "main"

        if "frida" in symbol.name:
            symbol.name = symbol.name.replace("frida", random_name)

        if "FRIDA" in symbol.name:
            symbol.name = symbol.name.replace("FRIDA", random_name)

    all_patch_string = [
        "FridaScriptEngine",
        "GLib-GIO",
        "GDBusProxy",
        "GumScript",
        "GumJS",
        "GumV8",
        "GumQuick",
    ]
    for section in binary.sections:
        if section.name != ".rodata":
            continue
        for patch_str in all_patch_string:
            addr_all = section.search_all(patch_str)
            for addr in addr_all:
                patch = [ord(n) for n in list(patch_str)[::-1]]
                log_color(
                    f"[*] Patching section name={section.name} offset={hex(section.file_offset + addr)} "
                    f"orig:{patch_str} new:{''.join(list(patch_str)[::-1])}"
                )
                binary.patch_address(section.file_offset + addr, patch)

    binary.write(input_file)

    patch_bytes(input_file, [
        ("frida-agent", make_token(len("frida-agent"))),
        ("frida_agent_main", "main"),
        ("gum-js-loop", make_token(len("gum-js-loop"))),
        ("pool-frida", make_token(len("pool-frida"))),
        ("gmain", make_token(len("gmain"))),
        ("gdbus", make_token(len("gdbus"))),
        ("linjector", make_token(len("linjector"))),
        ("FridaScriptEngine", make_token(len("FridaScriptEngine"))),
        ("GDBusProxy", make_token(len("GDBusProxy"))),
        ("GLib-GIO", make_token(len("GLib-GIO"))),
        ("GumScript", make_token(len("GumScript"))),
        ("GumJS", make_token(len("GumJS"))),
        ("GumV8", make_token(len("GumV8"))),
        ("GumQuick", make_token(len("GumQuick"))),
    ])

    log_color("[*] Patch Finish")
