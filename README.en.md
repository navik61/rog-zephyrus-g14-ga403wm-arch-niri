# ROG Zephyrus G14 GA403WM (1.0) — Arch Linux, systemd-boot + UKI, niri, uwsm, noctalia

[Čeština](README.md) | **English**

A complete, tested setup of the **ASUS ROG Zephyrus G14 (2025) GA403WM** laptop on Arch Linux:
booting via **systemd-boot + UKI**, the **niri** compositor started through **uwsm**, the
**noctalia** shell/panel, hybrid graphics **AMD + NVIDIA (RTX 5060, Blackwell)**, ASUS tools
(asusctl, supergfxctl, keyd) and a number of solved problems specific to this model.

The repo contains no personal data — placeholders (`<VAS-PARTUUID>`, `/home/USER`, …) are used
instead and need to be replaced.

> Tested 2026-11: kernel `linux` 7.3.5, `nvidia-open-dkms` 620.73, Mesa 26.3, niri 26.04,
> noctalia 5.6, asusctl 6.5, supergfxctl 5.2.
>
> Comments inside the config files are in Czech; all documentation exists in both languages
> (`*.en.md`).

## Hardware

| | |
|---|---|
| Model | ASUS ROG Zephyrus G14 GA403WM (board rev. 1.0) |
| CPU / iGPU | AMD Ryzen AI (Strix Point), Radeon 880M/890M — `amdgpu`, internal display `eDP-1` |
| dGPU | NVIDIA GeForce RTX 5060 Laptop (GB206) — **open modules only** (`nvidia-open-dkms`) |
| Keyboard | ITE `0b05:19b6` (Aura, type `19b6`) |
| Disk | NVMe, ESP (vfat) at `/boot`, root ext4 |

## Repository layout

```
system/            files for / (paths mirror their location on the system)
  boot/loader/loader.conf
  etc/kernel/cmdline                    kernel parameters (baked into the UKI)
  etc/mkinitcpio.d/linux.preset         build a UKI instead of an initramfs
  etc/mkinitcpio.conf.d/asus.conf       ASUS modules in the UKI
  etc/mkinitcpio.conf.excerpt           MODULES/HOOKS from mkinitcpio.conf (for reference)
  etc/modprobe.d/                       nvidia (RTD3, S0ix), supergfxd, btusb, camera off
  etc/udev/rules.d/                     Aura hidraw symlink, BT without autosuspend, Thunderbolt
  etc/systemd/system/                   aura-key-watch, nvidia-rtd3-rebind, paccache override
  etc/systemd/zram-generator.conf       zram (zstd), zswap disabled on the cmdline
  etc/pacman.d/hooks/                   bootctl update, Czech noctalia translation
  etc/asusd/                            asusd, fan curves, Aura modes for GA403WM
  etc/supergfxd.conf                    Hybrid mode
  etc/keyd/default.conf                 CapsLock = Ctrl/Esc, F23 → Print
  etc/xdg/reflector/reflector.conf
  usr/local/bin/aura-key-watch.py       working AURA key (Fn+F4)
  usr/local/sbin/nvidia-rtd3-rebind     workaround for dGPU runtime suspend on kernel 7.3+
dotfiles/          GNU stow packages (target = ~)
  niri/            config.kdl, noctalia.kdl (colors), scripts/ (ASUS profiles, brightness modes)
  uwsm/            env, env-niri, default-id, uwsm-status-niri.sh
  noctalia/        settings.json, plugins.json, templates
  environment.d/   LC_TIME, GDK_GL, DRI_PRIME, LIBVA
  xdg-desktop-portal/  niri-portals.conf, portals.conf
  systemd/         user services: noctalia, swayidle, asus-profile-notify, portal drop-ins
  gtk/ qt/ kitty/ foot/ fuzzel/
  sezeni/          ~/.local/bin/sezeni – save/restore niri window layout
packages/          pacman.txt, aur.txt – required packages
docs/              detailed guides and solved problems
```

## Quick start

> Nothing is installed automatically. Copy files from `system/` manually and deliberately —
> they are GA403WM-specific and some (camera off, Thunderbolt auto-authorize) are a matter of taste.

### 1. Packages

```bash
sudo pacman -S --needed $(grep -v '^#' packages/pacman.txt)
paru -S --needed supergfxctl wl-gammarelay-rs kando-bin      # see packages/aur.txt
```

### 2. Boot: systemd-boot + UKI

```bash
sudo bootctl install
sudo install -Dm644 system/boot/loader/loader.conf /boot/loader/loader.conf
sudo install -Dm644 system/etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux.preset
sudo install -Dm644 system/etc/mkinitcpio.conf.d/asus.conf /etc/mkinitcpio.conf.d/asus.conf
sudo install -Dm644 system/etc/kernel/cmdline /etc/kernel/cmdline
# fill in your root PARTUUID:
sudo sed -i "s/<VAS-PARTUUID>/$(findmnt -no PARTUUID /)/" /etc/kernel/cmdline
sudo install -Dm644 system/etc/pacman.d/hooks/95-systemd-boot.hook /etc/pacman.d/hooks/95-systemd-boot.hook
sudo mkinitcpio -P        # → Creating unified kernel image: '/boot/EFI/Linux/arch-linux.efi'
```

systemd-boot finds the UKI in `/boot/EFI/Linux/` on its own, no `loader/entries/*.conf` needed.
`default @saved` remembers the last selected entry.

**Kernel parameters** (`/etc/kernel/cmdline`):

| Parameter | Why |
|---|---|
| `zswap.enabled=0` | zram is used (`zram-generator.conf`), zswap would compete with it |
| `amd_pstate=active` | EPP-based CPU frequency control |
| `nvme_core.default_ps_max_latency_us=0` | disables NVMe APST (prevents disk freezes) |

**When to rebuild the UKI (`sudo mkinitcpio -P`):** after every change to `/etc/kernel/cmdline`
and `/etc/mkinitcpio.conf*`. Kernel/driver updates trigger it automatically via pacman hook.

### 3. GPU (AMD + NVIDIA)

```bash
sudo install -Dm644 system/etc/modprobe.d/nvidia.conf /etc/modprobe.d/nvidia.conf
sudo install -Dm755 system/usr/local/sbin/nvidia-rtd3-rebind /usr/local/sbin/nvidia-rtd3-rebind
sudo install -Dm644 system/etc/systemd/system/nvidia-rtd3-rebind.service /etc/systemd/system/
sudo systemctl enable nvidia-suspend nvidia-hibernate nvidia-resume nvidia-rtd3-rebind
sudo systemctl enable --now nvidia-powerd supergfxd
supergfxctl -m Hybrid
```

**Do not enable** `nvidia-persistenced` (it would keep the dGPU awake). Details, including RTD3
verification and running apps on the iGPU only: [docs/gpu-nvidia-amd.en.md](docs/gpu-nvidia-amd.en.md).

### 4. ASUS (asusctl, Aura, keyboard)

```bash
sudo install -Dm644 -t /etc/asusd system/etc/asusd/*.ron
sudo install -Dm644 system/etc/udev/rules.d/99-aura-hidraw.rules /etc/udev/rules.d/
sudo install -Dm755 system/usr/local/bin/aura-key-watch.py /usr/local/bin/aura-key-watch.py
sudo install -Dm644 system/etc/systemd/system/aura-key-watch.service /etc/systemd/system/
sudo install -Dm644 system/etc/keyd/default.conf /etc/keyd/default.conf
sudo udevadm control --reload && sudo udevadm trigger
sudo systemctl restart asusd
sudo systemctl enable --now aura-key-watch keyd
```

- `asusd_user_ledmodes.ron` — GA403WM is missing from upstream `aura_support.ron`; without it only Static works.
- `fan_curves.ron` — custom curves for quiet/balanced/performance.
- `aura-key-watch` — Fn+F4 cycles RGB effects (the kernel ignores this key).
- `keyd` — CapsLock: hold = Ctrl, tap = Esc; Esc = CapsLock; F23 → Print.
- `power-profiles-daemon` is masked (`systemctl mask power-profiles-daemon`), profiles are handled by asusd.

### 5. Other system files (optional)

| File | Purpose |
|---|---|
| `modprobe.d/btusb.conf` + `udev/…/50-bluetooth-no-autosuspend.rules` | Bluetooth without autosuspend (dropouts) |
| `modprobe.d/camera-off.conf` | webcam permanently disabled (`uvcvideo`) |
| `udev/…/99-removable.rules` | automatic authorization of Thunderbolt devices (dock) — a security trade-off |
| `systemd/zram-generator.conf` | zram ~½ RAM, zstd |
| `systemd/system/paccache.service.d/override.conf` | keeps 3 package versions, removes uninstalled ones and leftover downloads |
| `xdg/reflector/reflector.conf` | CZ/DE mirrors, https, sorted by speed (`reflector.timer`) |
| `pacman.d/hooks/noctalia-cs.hook` | restores the Czech translation after a noctalia update ([noctalia-cs](https://github.com/navik61/noctalia-cs)) |

### 6. Desktop: niri + uwsm + noctalia

```bash
cd dotfiles
stow --no-folding -t ~ niri uwsm noctalia environment.d xdg-desktop-portal systemd gtk qt kitty foot fuzzel sezeni
systemctl --user daemon-reload
systemctl --user enable noctalia.service swayidle.service asus-profile-notify.service
```

> **`--no-folding`** matters — otherwise stow links whole directories and applications would
> store their state inside the repository. Back up existing files first.

Starting the session from a TTY (e.g. in `~/.zprofile`):

```bash
if uwsm check may-start; then exec uwsm start default; fi
```

`~/.config/uwsm/default-id` contains `niri.desktop`. Environment variables: generic ones in
`uwsm/env`, niri-specific ones in `uwsm/env-niri` (selecting the AMD iGPU as render node).

**What is where:**

- `niri/config.kdl` — input (touchpad, tablet), outputs (eDP-1 scale 1.5 + external monitors),
  window rules, key bindings. Border colors come from `noctalia.kdl` (generated by noctalia
  from the wallpaper, `include "noctalia.kdl"`).
- `niri/scripts/sleep_modes.sh` — **Ctrl+1…5**: time-of-day modes (panel brightness, DDC/CI of
  the external monitor, color temperature via wl-gammarelay-rs).
- `niri/scripts/asus-profile-*.sh` + `asus-profile-notify.service` — notification when the ASUS
  profile changes (Fn+F5) using inotify on `/sys/firmware/acpi/platform_profile`.
- `systemd/noctalia.service` — noctalia as a user service bound to `graphical-session.target`.
- `systemd/swayidle.service` — turns monitors off after 10 min (`niri msg action power-off-monitors`).
- `systemd/xdg-desktop-portal-*.service.d/` — portals bound to the graphical session;
  `UnsetEnvironment=GDK_BACKEND` for the gnome portal (otherwise ScreenCast does not work).
- `noctalia/settings.json` — panel, plugins (supergfxctl, battery-threshold, polkit-agent, …),
  the weather location is a placeholder (`Prague`), wallpapers in `~/Pictures/`.
- `qt/qt5ct.conf` — contains the absolute path `/home/USER/...`, change it to your home.
- `sezeni` — saves and restores the window layout: [docs/niri-sezeni.en.md](docs/niri-sezeni.en.md).

Notable shortcuts: `Mod+Return` kitty, `Mod+D` fuzzel, `Mod+n` notes (noctalia),
`Mod+S` Kando, `Mod+Shift+Z` / `Mod+Alt+L` lock, `Ctrl+1…5` brightness modes. Full overview:
`Mod+/` in niri.

## Documentation

- [docs/gpu-nvidia-amd.en.md](docs/gpu-nvidia-amd.en.md) — drivers, RTD3 workaround, iGPU-only apps, verification
- [docs/tipy-a-problemy.en.md](docs/tipy-a-problemy.en.md) — dead `Mod` shortcuts (Fn+Super lock), OBS/portals, Aura key, BT
- [docs/asusctl-aura-ga403wm.en.md](docs/asusctl-aura-ga403wm.en.md) — Aura support analysis and the Fn+F4 HID report
- [docs/niri-displaylink.md](docs/niri-displaylink.md) — DisplayLink dock (evdi) in niri on AMD+NVIDIA
- [docs/niri-sezeni.en.md](docs/niri-sezeni.en.md) — saving/restoring window sessions

## Troubleshooting (short)

| Symptom | Fix |
|---|---|
| All `Mod+…` shortcuts are dead | Fn+Super (firmware Win-key lock), see docs |
| OBS can't see windows | gnome portal + `UnsetEnvironment=GDK_BACKEND`, not wlr |
| dGPU never `suspended` | `grep 'Runtime D3' /proc/driver/nvidia/gpus/*/power`, `journalctl -b -u nvidia-rtd3-rebind` |
| cmdline change has no effect | `sudo mkinitcpio -P` and reboot |
| RGB only Static | `/etc/asusd/asusd_user_ledmodes.ron` is missing |
| Fn+F4 does nothing | `systemctl status aura-key-watch`, `ls -l /dev/aura-hidraw` |
| niri doesn't use AMD as render node | `uwsm/env-niri` (`NIRI_RENDER_NODE`, `DRI_PRIME`) — verify PCI addresses with `lspci` |

## Related projects

- [noctalia-cs](https://github.com/navik61/noctalia-cs) — Czech translation of noctalia
- [fzfex](https://github.com/navik61/fzfex) — fzf with previews in niri windows
- [viim](https://github.com/navik61/viim) — transparent image viewer for niri

## License

MIT — see [LICENSE](LICENSE). Use the configuration at your own risk; `system/` in particular
changes kernel, boot and hardware behavior.
