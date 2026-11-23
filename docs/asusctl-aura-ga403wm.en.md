# Adding ASUS ROG Zephyrus G14 GA403WM support to aura_support.ron

[Čeština](asusctl-aura-ga403wm.md) | **English**

## Where to send it
GitLab: https://gitlab.com/asus-linux/asusctl (or the GitHub fork
OpenGamingCollective/asusctl, depending on where upstream currently lives)

File path in the repo: rog-aura/data/aura_support.ron

## Problem description (for an issue/MR)

GA403WM (ROG Zephyrus G14, 2025, Aura type 19b6) is missing from aura_support.ron.
asusd therefore falls back to a default with only the Static mode:

    [WARN  rog_aura::aura_detection] the aura_support.ron file has no
    entry for this model: GA403WM, 19b6. Using a default

Sibling models of the same generation (GA403UV, GA403WR, GA403WW) are already in the file,
all with the same layout_name "ga401q" and an identical set of basic_modes. GA403WM shares the
same keyboard/LED board (ITE Tech. Inc. ITE Device, HID 0B05:19B6) – only the GPU/CPU
configuration in the model name differs, not the physical Aura control.

Tested locally via the /etc/asusd/asusd_user_ledmodes.ron override – with the entry below
Static, Breathe, RainbowCycle, RainbowWave and Pulse all work without errors (no NotSupported
D-Bus errors).

asusctl version during testing: 6.3.8
Kernel: Arch Linux, current

## Note on the physical AURA key (Fn+F4) – outside the scope of this MR

This MR only fixes asusd not knowing the GA403WM model in aura_support.ron, so software
(CLI/GUI) can set only the Static effect. A separate, unrelated problem is that the physical
AURA key (Fn+F4) on the keyboard does nothing, even after the fix above.

Found with hid-recorder on /dev/hidraw0 (ITE Tech. Inc. ITE Device, HID 0B05:19B6): on press
the key sends its own 2-byte HID report – Report ID 0x5a (90), value 0xb3 on press, 0x00 on
release, through a separate vendor-specific collection (Usage Page 0xff31, Usage 0x76). The
kernel driver hid-asus.c does not handle this report ID at all – it only handles Report ID 1
(standard keyboard), where spurious code filtering and the recently added Fn+F5 support live
(see the January 2026 patch: "HID: asus: Add Fn+F5 fan control key support").

Interestingly, the value 0xb3 exactly matches the older ACPI/WMI keymap entry
`{ KE_KEY, 0xB3, { KEY_PROG4 } } /* AURA */` in asus-nb-wmi.c – this model just sends the same
value via a different (HID vendor) path that neither asus-nb-wmi.c nor hid-asus.c covers.

Until this gets a kernel patch (analogous to Fn+F5), the key stays non-functional for anyone
who doesn't write their own userspace workaround reading /dev/hidraw directly. A working
Python/systemd solution (reading raw HID reports, running `asusctl aura effect --next-mode` on
press) is in this repository: `system/usr/local/bin/aura-key-watch.py`,
`system/etc/systemd/system/aura-key-watch.service`, `system/etc/udev/rules.d/99-aura-hidraw.rules`.

## Proposed diff for aura_support.ron

Add next to the existing GA403UV/GA403WR/GA403WW entries:

    (
        device_name: "GA403WM",
        product_id: "",
        layout_name: "ga401q",
        basic_modes: [Static, Breathe, RainbowCycle, RainbowWave, Pulse],
        basic_zones: [],
        advanced_type: r#None,
        power_zones: [Keyboard],
    ),

## How to submit (GitLab web UI, no local git needed)

1. Open rog-aura/data/aura_support.ron in the repo on gitlab.com
2. Click Edit (pencil) – GitLab automatically creates a fork in your account if you don't have
   direct write access
3. Find the section with GA403UV / GA403WR / GA403WW (sorted alphabetically by device_name, so
   GA403WM goes between GA403WR and GA403WW, or simply right after GA403UV)
4. Insert the new entry from the diff above
5. At the bottom choose "Commit changes" -> "Start a new merge request"
6. MR title: "Add aura support for ASUS ROG Zephyrus G14 GA403WM"
7. Paste the text from "Problem description" above into the description
