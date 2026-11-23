#!/usr/bin/env python3
"""
Watcher pro fyzickou AURA klávesu (Fn+F4) na ASUS ROG G14 (GA403WM).

Klávesa posílá vlastní 2bajtový HID report (Report ID 0x5a / 90,
Vendor Usage Page 0xff31), který kernelový driver hid-asus.c vůbec
nezpracovává (stará se jen o Report ID 1 - standardní klávesnici).
Tenhle skript čte syrové reporty přímo z /dev/hidraw0 (nebo stabilního
symlinku vytvořeného udev pravidlem) a na stisk (0x5a 0xb3) spustí
asusctl pro cyklení Aura RGB efektů.
"""

import subprocess
import sys

DEVICE = "/dev/aura-hidraw"  # stabilní symlink z udev pravidla
PRESS = bytes([0x5a, 0xb3])
READ_SIZE = 64


def trigger():
    subprocess.run(
        ["asusctl", "aura", "effect", "--next-mode"],
        check=False,
    )


def main():
    try:
        with open(DEVICE, "rb", buffering=0) as f:
            while True:
                data = f.read(READ_SIZE)
                if len(data) >= 2 and data[0:2] == PRESS:
                    trigger()
    except FileNotFoundError:
        print(f"Zařízení {DEVICE} nenalezeno - zkontroluj udev pravidlo.",
              file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"Nedostatečná oprávnění pro {DEVICE} - služba musí běžet jako root.",
              file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
