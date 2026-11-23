#!/usr/bin/env python3
"""
Watcher for the physical AURA key (Fn+F4) on the ASUS ROG G14 (GA403WM).

The key sends its own 2-byte HID report (Report ID 0x5a / 90,
Vendor Usage Page 0xff31), which the kernel driver hid-asus.c does not
handle at all (it only handles Report ID 1 - the standard keyboard).
This script reads raw reports directly from /dev/hidraw0 (or the stable
symlink created by the udev rule) and on key press (0x5a 0xb3) runs
asusctl to cycle Aura RGB effects.
"""

import subprocess
import sys

DEVICE = "/dev/aura-hidraw"  # stable symlink from the udev rule
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
        print(f"Device {DEVICE} not found - check the udev rule.",
              file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"Insufficient permissions for {DEVICE} - the service must run as root.",
              file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
