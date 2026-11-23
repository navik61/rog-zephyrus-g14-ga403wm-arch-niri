# ROG Zephyrus G14 GA403WM (1.0) — Arch Linux, systemd-boot + UKI, niri, uwsm, noctalia

**Čeština** | [English](README.en.md)

Kompletní a ověřené nastavení notebooku **ASUS ROG Zephyrus G14 (2025) GA403WM** na Arch Linuxu:
boot přes **systemd-boot + UKI**, kompozitor **niri** spouštěný přes **uwsm**, shell/panel
**noctalia**, hybridní grafika **AMD + NVIDIA (RTX 5060, Blackwell)**, ASUS nástroje
(asusctl, supergfxctl, keyd) a řada vyřešených problémů specifických pro tento model.

Repo neobsahuje žádná osobní data — místo nich jsou zástupné hodnoty (`<VAS-PARTUUID>`,
`/home/USER`, …), které je potřeba nahradit.

> Ověřeno 2026-11: jádro `linux` 7.3.5, `nvidia-open-dkms` 620.73, Mesa 26.3, niri 26.04,
> noctalia 5.6, asusctl 6.5, supergfxctl 5.2.

## Hardware

| | |
|---|---|
| Model | ASUS ROG Zephyrus G14 GA403WM (board rev. 1.0) |
| CPU / iGPU | AMD Ryzen AI (Strix Point), Radeon 880M/890M — `amdgpu`, interní displej `eDP-1` |
| dGPU | NVIDIA GeForce RTX 5060 Laptop (GB206) — **jen open moduly** (`nvidia-open-dkms`) |
| Klávesnice | ITE `0b05:19b6` (Aura, typ `19b6`) |
| Disk | NVMe, ESP (vfat) na `/boot`, root ext4 |

## Struktura repozitáře

```
system/            soubory pro / (cesty zrcadlí umístění v systému)
  boot/loader/loader.conf
  etc/kernel/cmdline                    parametry jádra (zapečené v UKI)
  etc/mkinitcpio.d/linux.preset         generování UKI místo initramfs
  etc/mkinitcpio.conf.d/asus.conf       ASUS moduly do UKI
  etc/mkinitcpio.conf.excerpt           MODULES/HOOKS z mkinitcpio.conf (pro srovnání)
  etc/modprobe.d/                       nvidia (RTD3, S0ix), supergfxd, btusb, kamera off
  etc/udev/rules.d/                     Aura hidraw symlink, BT bez autosuspendu, Thunderbolt
  etc/systemd/system/                   aura-key-watch, nvidia-rtd3-rebind, paccache override
  etc/systemd/zram-generator.conf       zram (zstd), zswap vypnutý v cmdline
  etc/pacman.d/hooks/                   bootctl update, český překlad noctalie
  etc/asusd/                            asusd, ventilátorové křivky, Aura módy pro GA403WM
  etc/supergfxd.conf                    režim Hybrid
  etc/keyd/default.conf                 CapsLock = Ctrl/Esc, F23 → Print
  etc/xdg/reflector/reflector.conf
  usr/local/bin/aura-key-watch.py       funkční klávesa AURA (Fn+F4)
  usr/local/sbin/nvidia-rtd3-rebind     workaround uspávání dGPU na jádře 7.3+
dotfiles/          balíčky pro GNU stow (cíl = ~)
  niri/            config.kdl, noctalia.kdl (barvy), scripts/ (ASUS profily, denní režimy jasu)
  uwsm/            env, env-niri, default-id, uwsm-status-niri.sh
  noctalia/        settings.json, plugins.json, šablony
  environment.d/   LC_TIME, GDK_GL, DRI_PRIME, LIBVA
  xdg-desktop-portal/  niri-portals.conf, portals.conf
  systemd/         user služby: noctalia, swayidle, asus-profile-notify, portal drop-iny
  gtk/ qt/ kitty/ foot/ fuzzel/
  sezeni/          ~/.local/bin/sezeni – uložení/obnova rozložení oken v niri
packages/          pacman.txt, aur.txt – potřebné balíčky
docs/              podrobné návody a vyřešené problémy
```

## Rychlé použití

> Nic se neinstaluje automaticky. Soubory v `system/` kopíruj ručně a vědomě — jsou
> specifické pro GA403WM a některé (kamera off, Thunderbolt auto-authorize) jsou věcí vkusu.

### 1. Balíčky

```bash
sudo pacman -S --needed $(grep -v '^#' packages/pacman.txt)
paru -S --needed supergfxctl wl-gammarelay-rs kando-bin      # viz packages/aur.txt
```

### 2. Boot: systemd-boot + UKI

```bash
sudo bootctl install
sudo install -Dm644 system/boot/loader/loader.conf /boot/loader/loader.conf
sudo install -Dm644 system/etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux.preset
sudo install -Dm644 system/etc/mkinitcpio.conf.d/asus.conf /etc/mkinitcpio.conf.d/asus.conf
sudo install -Dm644 system/etc/kernel/cmdline /etc/kernel/cmdline
# doplň vlastní PARTUUID rootu:
sudo sed -i "s/<VAS-PARTUUID>/$(findmnt -no PARTUUID /)/" /etc/kernel/cmdline
sudo install -Dm644 system/etc/pacman.d/hooks/95-systemd-boot.hook /etc/pacman.d/hooks/95-systemd-boot.hook
sudo mkinitcpio -P        # → Creating unified kernel image: '/boot/EFI/Linux/arch-linux.efi'
```

systemd-boot najde UKI v `/boot/EFI/Linux/` sám, žádné `loader/entries/*.conf` nejsou potřeba.
`default @saved` si pamatuje naposledy zvolenou položku.

**Parametry jádra** (`/etc/kernel/cmdline`):

| Parametr | Proč |
|---|---|
| `zswap.enabled=0` | používá se zram (`zram-generator.conf`), zswap by se s ním pral |
| `amd_pstate=active` | EPP řízení frekvencí CPU |
| `nvme_core.default_ps_max_latency_us=0` | vypne APST na NVMe (prevence zamrznutí disku) |

**Kdy přegenerovat UKI (`sudo mkinitcpio -P`):** po každé změně `/etc/kernel/cmdline`
a `/etc/mkinitcpio.conf*`. Aktualizace jádra/ovladačů to udělá pacman hook sám.

### 3. GPU (AMD + NVIDIA)

```bash
sudo install -Dm644 system/etc/modprobe.d/nvidia.conf /etc/modprobe.d/nvidia.conf
sudo install -Dm755 system/usr/local/sbin/nvidia-rtd3-rebind /usr/local/sbin/nvidia-rtd3-rebind
sudo install -Dm644 system/etc/systemd/system/nvidia-rtd3-rebind.service /etc/systemd/system/
sudo systemctl enable nvidia-suspend nvidia-hibernate nvidia-resume nvidia-rtd3-rebind
sudo systemctl enable --now nvidia-powerd supergfxd
supergfxctl -m Hybrid
```

`nvidia-persistenced` **nepovolovat** (držel by dGPU vzhůru). Podrobně, včetně ověření
RTD3 a spouštění aplikací jen na iGPU: [docs/gpu-nvidia-amd.md](docs/gpu-nvidia-amd.md).

### 4. ASUS (asusctl, Aura, klávesnice)

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

- `asusd_user_ledmodes.ron` — GA403WM chybí v upstream `aura_support.ron`, bez něj funguje jen Static.
- `fan_curves.ron` — vlastní křivky pro quiet/balanced/performance.
- `aura-key-watch` — Fn+F4 cykluje RGB efekty (jádro tu klávesu ignoruje).
- `keyd` — CapsLock: podržení = Ctrl, ťuknutí = Esc; Esc = CapsLock; F23 → Print.
- `power-profiles-daemon` je maskovaný (`systemctl mask power-profiles-daemon`), profily řídí asusd.

### 5. Ostatní systémové soubory (volitelné)

| Soubor | Účel |
|---|---|
| `modprobe.d/btusb.conf` + `udev/…/50-bluetooth-no-autosuspend.rules` | BT bez autosuspendu (vypadávání) |
| `modprobe.d/camera-off.conf` | trvale vypnutá webkamera (`uvcvideo`) |
| `udev/…/99-removable.rules` | automatická autorizace Thunderbolt zařízení (dock) — bezpečnostní kompromis |
| `systemd/zram-generator.conf` | zram ~½ RAM, zstd |
| `systemd/system/paccache.service.d/override.conf` | ponechá 3 verze balíčků, smaže odinstalované a zbytky stahování |
| `xdg/reflector/reflector.conf` | mirrory CZ/DE, https, seřazené podle rychlosti (`reflector.timer`) |
| `pacman.d/hooks/noctalia-cs.hook` | po aktualizaci noctalie vrátí český překlad ([noctalia-cs](https://github.com/navik61/noctalia-cs)) |

### 6. Desktop: niri + uwsm + noctalia

```bash
cd dotfiles
stow --no-folding -t ~ niri uwsm noctalia environment.d xdg-desktop-portal systemd gtk qt kitty foot fuzzel sezeni
systemctl --user daemon-reload
systemctl --user enable noctalia.service swayidle.service asus-profile-notify.service
```

> **`--no-folding`** je důležité — jinak stow nalinkuje celé adresáře a aplikace by si ukládaly
> stav do repozitáře. Existující soubory si předtím zazálohuj.

Spuštění session z TTY (např. v `~/.zprofile`):

```bash
if uwsm check may-start; then exec uwsm start default; fi
```

`~/.config/uwsm/default-id` obsahuje `niri.desktop`. Proměnné prostředí: obecné v
`uwsm/env`, specifické pro niri v `uwsm/env-niri` (výběr AMD iGPU jako render node).

**Co je kde:**

- `niri/config.kdl` — vstupy (touchpad, tablet), výstupy (eDP-1 scale 1.5 + externí monitory),
  window rules, klávesové zkratky. Barvy rámečků přicházejí z `noctalia.kdl` (generuje noctalia
  podle tapety, `include "noctalia.kdl"`).
- `niri/scripts/sleep_modes.sh` — **Ctrl+1…5**: denní režimy (jas panelu, DDC/CI externího
  monitoru, teplota barev přes wl-gammarelay-rs).
- `niri/scripts/asus-profile-*.sh` + `asus-profile-notify.service` — notifikace při změně
  ASUS profilu (Fn+F5) přes inotify na `/sys/firmware/acpi/platform_profile`.
- `systemd/noctalia.service` — noctalia jako user služba vázaná na `graphical-session.target`.
- `systemd/swayidle.service` — po 10 min vypne monitory (`niri msg action power-off-monitors`).
- `systemd/xdg-desktop-portal-*.service.d/` — portály vázané na grafickou session;
  pro gnome portál `UnsetEnvironment=GDK_BACKEND` (jinak nefunguje ScreenCast).
- `noctalia/settings.json` — panel, pluginy (supergfxctl, battery-threshold, polkit-agent, …),
  lokace počasí je zástupná (`Prague`), tapety v `~/Pictures/`.
- `qt/qt5ct.conf` — obsahuje absolutní cestu `/home/USER/...`, uprav na svůj domov.
- `sezeni` — uloží a obnoví rozložení oken: [docs/niri-sezeni.md](docs/niri-sezeni.md).

Zkratky, které stojí za zmínku: `Mod+Return` kitty, `Mod+D` fuzzel, `Mod+n` poznámky (noctalia),
`Mod+S` Kando, `Mod+Shift+Z` / `Mod+Alt+L` zámek, `Ctrl+1…5` režimy jasu. Celý přehled:
`Mod+/` v niri.

## Dokumentace

Každý návod má i anglickou verzi (`*.en.md`); `niri-displaylink.md` je jen anglicky.

- [docs/gpu-nvidia-amd.md](docs/gpu-nvidia-amd.md) — ovladače, RTD3 workaround, iGPU-only aplikace, ověření
- [docs/tipy-a-problemy.md](docs/tipy-a-problemy.md) — mrtvé `Mod` zkratky (Fn+Super zámek), OBS/portály, Aura klávesa, BT
- [docs/asusctl-aura-ga403wm.md](docs/asusctl-aura-ga403wm.md) — analýza Aura podpory a HID reportu klávesy Fn+F4
- [docs/niri-displaylink.md](docs/niri-displaylink.md) — DisplayLink dock (evdi) v niri na AMD+NVIDIA
- [docs/niri-sezeni.md](docs/niri-sezeni.md) — ukládání/obnova sezení oken

## Řešení problémů (stručně)

| Příznak | Řešení |
|---|---|
| Všechny `Mod+…` zkratky nefungují | Fn+Super (firmwarový zámek Win klávesy), viz docs |
| OBS nevidí okna | gnome portál + `UnsetEnvironment=GDK_BACKEND`, ne wlr |
| dGPU nikdy `suspended` | `grep 'Runtime D3' /proc/driver/nvidia/gpus/*/power`, `journalctl -b -u nvidia-rtd3-rebind` |
| Po změně cmdline se nic neděje | `sudo mkinitcpio -P` a restart |
| RGB jen Static | chybí `/etc/asusd/asusd_user_ledmodes.ron` |
| Fn+F4 nic nedělá | `systemctl status aura-key-watch`, `ls -l /dev/aura-hidraw` |
| niri nepoužívá AMD jako render node | `uwsm/env-niri` (`NIRI_RENDER_NODE`, `DRI_PRIME`) — PCI adresy ověř přes `lspci` |

## Související projekty

- [noctalia-cs](https://github.com/navik61/noctalia-cs) — český překlad noctalie
- [fzfex](https://github.com/navik61/fzfex) — fzf s náhledy v oknech niri
- [viim](https://github.com/navik61/viim) — průhledný prohlížeč obrázků pro niri

## Licence

MIT — viz [LICENSE](LICENSE). Konfigurace přebírej na vlastní riziko; zejména `system/` mění
chování jádra, bootu a hardwaru.
