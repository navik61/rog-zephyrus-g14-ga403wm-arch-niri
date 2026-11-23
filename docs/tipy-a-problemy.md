# Tipy a vyřešené problémy

**Čeština** | [English](tipy-a-problemy.en.md)

## Všechny `Mod+…` zkratky v niri najednou přestaly fungovat

Na GA403WM (klávesnice ITE `0b05:19b6`) přepíná **Fn+Super** firmwarový zámek klávesy Win.
Když je zapnutý, `KEY_LEFTMETA` vůbec nedorazí (ani do virtuální klávesnice keyd, ani do
libinput) a všechny zkratky s `Mod` jsou mrtvé. Zámek přežije i restart.

Kontrola:

```bash
sudo libinput debug-events --show-keycodes   # stiskni Super – chybí KEY_LEFTMETA?
```

Řešení: stisknout **Fn+Super** (někdy i několikrát). Přes sysfs/asusctl/asus-armoury ho
vypnout nejde a stav zámku nelze spolehlivě zjistit (v režimu zámku klávesa neposílá žádný HID
report). Případný workaround: v keyd namapovat záložní klávesu na `meta`.

## Snímání okna / obrazovky (OBS, screen sharing) přes portál

`~/.config/uwsm/env` exportuje `GDK_BACKEND=wayland,x11,*`. Tím se
`xdg-desktop-portal-gnome` spustí v režimu „settings only“ (bez ScreenCast) a v logu je
`Non-compatible display server`.

Oprava: drop-in `~/.config/systemd/user/xdg-desktop-portal-gnome.service.d/unset-gdk-backend.conf`

```ini
[Service]
UnsetEnvironment=GDK_BACKEND
```

a v `niri-portals.conf` **nenastavovat** `ScreenCast/Screenshot=wlr` – wlr portál umí jen
celé výstupy, ne jednotlivá okna. V OBS je zdroj okna „Záznam okna (PipeWire)“
(*Window Capture (PipeWire)*).

```bash
systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal-gnome xdg-desktop-portal
```

## Fyzická klávesa AURA (Fn+F4) nic nedělá

Klávesa posílá vlastní HID report (Report ID `0x5a`, hodnota `0xb3`), který jádro
(`hid-asus`) nezpracovává. Řeší to `aura-key-watch.py` + `aura-key-watch.service` + udev
pravidlo `99-aura-hidraw.rules` (stabilní `/dev/aura-hidraw`). Na stisk spustí
`asusctl aura effect --next-mode`. Detaily a návrh upstream opravy:
[asusctl-aura-ga403wm.md](asusctl-aura-ga403wm.md).

## asusd zná jen „Static“ RGB efekt

GA403WM chybí v `aura_support.ron`. Override `/etc/asusd/asusd_user_ledmodes.ron`
(v repu) přidá Static, Breathe, RainbowCycle, RainbowWave a Pulse.

## dGPU se nikdy neuspí (RTD3 „Not supported“) na jádře 7.3+

Viz [gpu-nvidia-amd.md](gpu-nvidia-amd.md#6-rtd3-workaround-pro-jádro-73-dočasné) –
`nvidia-rtd3-rebind` + služba.

## Bluetooth vypadává

Autosuspend USB Bluetooth čipu (`0489:e11e`) je vypnutý: `modprobe.d/btusb.conf`
a `udev/rules.d/50-bluetooth-no-autosuspend.rules`.

## Webkamera

`modprobe.d/camera-off.conf` blokuje `uvcvideo` (kamera trvale vypnutá). Pokud ji chceš,
soubor neinstaluj.
