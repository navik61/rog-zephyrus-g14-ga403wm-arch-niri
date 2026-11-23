# Tips and solved problems

[Čeština](tipy-a-problemy.md) | **English**

## All `Mod+…` shortcuts in niri suddenly stopped working

On the GA403WM (ITE keyboard `0b05:19b6`) **Fn+Super** toggles a firmware lock of the Win key.
When it is on, `KEY_LEFTMETA` never arrives (neither in the keyd virtual keyboard nor in
libinput) and every `Mod` shortcut is dead. The lock survives a reboot.

Check:

```bash
sudo libinput debug-events --show-keycodes   # press Super – is KEY_LEFTMETA missing?
```

Fix: press **Fn+Super** (sometimes several times). It cannot be disabled via
sysfs/asusctl/asus-armoury and the lock state cannot be detected reliably (while locked the key
sends no HID report at all). Possible workaround: map a fallback key to `meta` in keyd.

## Window / screen capture (OBS, screen sharing) through the portal

`~/.config/uwsm/env` exports `GDK_BACKEND=wayland,x11,*`. This makes
`xdg-desktop-portal-gnome` start in "settings only" mode (no ScreenCast) and the log shows
`Non-compatible display server`.

Fix: drop-in `~/.config/systemd/user/xdg-desktop-portal-gnome.service.d/unset-gdk-backend.conf`

```ini
[Service]
UnsetEnvironment=GDK_BACKEND
```

and **do not set** `ScreenCast/Screenshot=wlr` in `niri-portals.conf` – the wlr portal can only
capture whole outputs, not single windows. In OBS the window source is
"Window Capture (PipeWire)".

```bash
systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal-gnome xdg-desktop-portal
```

## The physical AURA key (Fn+F4) does nothing

The key sends its own HID report (Report ID `0x5a`, value `0xb3`) which the kernel
(`hid-asus`) does not handle. This is solved by `aura-key-watch.py` + `aura-key-watch.service` +
the udev rule `99-aura-hidraw.rules` (stable `/dev/aura-hidraw`). On key press it runs
`asusctl aura effect --next-mode`. Details and a proposed upstream fix:
[asusctl-aura-ga403wm.en.md](asusctl-aura-ga403wm.en.md).

## asusd only knows the "Static" RGB effect

GA403WM is missing from `aura_support.ron`. The override `/etc/asusd/asusd_user_ledmodes.ron`
(in this repo) adds Static, Breathe, RainbowCycle, RainbowWave and Pulse.

## The dGPU never suspends (RTD3 "Not supported") on kernel 7.3+

See [gpu-nvidia-amd.en.md](gpu-nvidia-amd.en.md#6-rtd3-workaround-for-kernel-73-temporary) –
`nvidia-rtd3-rebind` + service.

## Bluetooth drops out

Autosuspend of the USB Bluetooth chip (`0489:e11e`) is disabled: `modprobe.d/btusb.conf`
and `udev/rules.d/50-bluetooth-no-autosuspend.rules`.

## Webcam

`modprobe.d/camera-off.conf` blacklists `uvcvideo` (camera permanently off). If you want the
camera, don't install that file.
