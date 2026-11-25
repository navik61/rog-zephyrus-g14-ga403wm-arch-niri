# GPU na ASUS ROG Zephyrus G14 GA403WM — instalace a nastavení

**Čeština** | [English](gpu-nvidia-amd.en.md)

Ověřeno 2026-11-25 na: jádro `linux` 7.3.6-arch1-1, `nvidia-open-dkms` 620.73.04,
Mesa 26.3.1, systemd-boot + UKI, kompozitor niri (uwsm).

## Hardware

| | Zařízení | PCI | Ovladač |
|---|---|---|---|
| iGPU | AMD Radeon 880M/890M (Strix) | `65:00.0` | `amdgpu` |
| dGPU | NVIDIA GeForce RTX 5060 Laptop (GB206, Blackwell) | `64:00.0` | `nvidia` (open) |

- **Režim:** `Hybrid` (supergfxctl), MUX = Optimus → interní displej (`eDP-1`) je na **AMD**,
  NVIDIA se probouzí jen na vyžádání (`prime-run`). Podsvícení řídí `amdgpu_bl1`.
- **HDMI a jeden DP/USB-C výstup** jsou zapojené na NVIDIA (`card0-HDMI-A-1`, `DP-*`) —
  externí monitor na nich dGPU probudí.
- Blackwell podporuje **jen open moduly** (`nvidia-open-dkms`), proprietární `nvidia-dkms` nefunguje.

---

## 1. Balíčky

```bash
# AMD (iGPU)
sudo pacman -S mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon

# NVIDIA (dGPU)
sudo pacman -S linux-headers nvidia-open-dkms nvidia-utils lib32-nvidia-utils \
               nvidia-settings nvidia-prime opencl-nvidia libva-nvidia-driver

# Společné / nástroje
sudo pacman -S vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools libva-utils nvtop

# ASUS (repo g14 nebo AUR)
asusctl supergfxctl
```

**Neinstalovat:**
- `nvidia-bl-dkms` — ovladač podsvícení pro staré MacBooky. Na G14 je k ničemu a s jádrem 7.3
  se nesestaví (chyba DKMS při každé aktualizaci jádra).
- `nvidia-dkms` (proprietární) — nepodporuje Blackwell.
- `xf86-video-nouveau` — `nouveau` je zablokovaný (viz níže).

---

## 2. Parametry jádra (UKI)

Soubor `/etc/kernel/cmdline`:

```
root=PARTUUID=… rw rootfstype=ext4 zswap.enabled=0 amd_pstate=active amdgpu.ppfeaturemask=0xffffffff nvme_core.default_ps_max_latency_us=0
```

| Parametr | Proč |
|---|---|
| `amd_pstate=active` | EPP řízení frekvencí CPU (šetří baterii) |
| `amdgpu.ppfeaturemask=0xffffffff` | *Volitelné.* Odemyká overdrive/undervolt iGPU. Bez potřeby ladit iGPU ho vyhoď — jádro jinak hlásí „Overdrive is enabled“ |
| `nvidia_drm.modeset=1` | *Nadbytečné.* Od ovladače 560 je to výchozí; navíc je to i v modprobe. Neškodí |

Po změně cmdline přegenerovat UKI:

```bash
sudo mkinitcpio -P
```

---

## 3. Moduly (`/etc/modprobe.d/`)

### `nvidia.conf` — doporučený obsah

```
options nvidia NVreg_EnableS0ixPowerManagement=1 NVreg_DynamicPowerManagement=0x02
```

- `NVreg_DynamicPowerManagement=0x02` — jemné uspávání dGPU (RTD3), když ji nikdo nepoužívá.
- `NVreg_EnableS0ixPowerManagement=1` — správný suspend do S0ix (modern standby).
- **`NVreg_EnableGpuFirmware=0` nepoužívat** — open ovladač na Blackwellu GSP firmware vyžaduje
  vždy, parametr nemá žádný účinek (jen mate). Odstraněno 2026-11-20; ověření po restartu:
  `sudo grep EnableGpuFirmware /proc/driver/nvidia/params` (má být výchozí hodnota, ne `0`).
- `options nvidia_drm modeset=1` — nadbytečné, lze vynechat.

### `supergfxd.conf` (generuje supergfxd, neupravovat)

```
blacklist nouveau
alias nouveau off
options nvidia-drm modeset=1
```

---

## 4. Initramfs (`/etc/mkinitcpio.conf`)

```
MODULES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
```

`/etc/mkinitcpio.conf.d/asus.conf`:

```
MODULES+=(hid_asus asus_wmi asus_nb_wmi)
```

- Moduly NVIDIA do initramfs **není potřeba přidávat** — displej je na AMD, early KMS pro NVIDIA
  nic nepřinese (jen větší UKI a nutnost přegenerovat ho při každé aktualizaci ovladače).
- Varování `Possibly missing firmware for module: 'nouveau'` je neškodné.

### Kdy přegenerovat UKI (`sudo mkinitcpio -P`)

Boot je systemd-boot + UKI: `/etc/mkinitcpio.d/linux.preset` má `default_uki=` a `mkinitcpio -P`
nevytváří samostatný initramfs, ale celý `/boot/EFI/Linux/arch-linux.efi` (jádro + initramfs +
cmdline + splash v jednom souboru). Ve výstupu má být
`Creating unified kernel image: '/boot/EFI/Linux/arch-linux.efi'`.

| Změna | Přegenerovat? |
|---|---|
| `/etc/kernel/cmdline` | **Vždy** — cmdline je zapečená v UKI |
| `/etc/mkinitcpio.conf`, `/etc/mkinitcpio.conf.d/*` | **Vždy** |
| `/etc/modprobe.d/*` | Jen pokud se modul načítá z initramfs. Hook `modconf` kopie souborů do UKI dává, ale moduly NVIDIA v něm nejsou — načítají se z disku a čtou aktuální `/etc/modprobe.d/`. Pro konzistenci ale klidně vždy |
| Aktualizace jádra / ovladače | Udělá pacman hook automaticky |

Změna se projeví až po restartu. Obsah UKI lze zkontrolovat:

```bash
sudo lsinitcpio /boot/EFI/Linux/arch-linux.efi | grep -E 'nvidia|modprobe.d'
```

---

## 5. Služby

```bash
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
sudo systemctl enable --now nvidia-powerd.service   # Dynamic Boost
sudo systemctl enable --now supergfxd.service
sudo systemctl enable nvidia-rtd3-rebind.service    # viz sekce 6
```

`nvidia-persistenced` **nepovolovat** — držel by dGPU stále vzhůru.

Režim GPU:

```bash
supergfxctl -g          # aktuální režim (má být Hybrid)
supergfxctl -m Hybrid   # iGPU + dGPU na vyžádání (doporučeno)
```

---

## 6. RTD3 workaround pro jádro 7.3+ (dočasné)

### Problém

Na jádře 7.3+ hlásí ovladač `Runtime D3 status: Not supported` a dGPU se **nikdy neuspí**
(~4 W navíc trvale). Příčina: od 7.3 běží kernelová vlákna v prázdném rootu (nullfs), probe
vlákno `nv-probe` neotevře `/sys/bus/pci/devices/…/config` a ovladač RTD3 potichu vypne.
Upstream: [NVIDIA/open-gpu-kernel-modules#1507](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1507)
(oprava = PR #1512, k 2026-11-20 nezačleněná; 620.73.04 je postižená).

Řešení: po bootu, **dřív než kartu kdokoli otevře**, ji odpojit a znovu připojit k ovladači
z běžného procesu.

### `/usr/local/sbin/nvidia-rtd3-rebind` (`chmod 755`)

```sh
#!/bin/sh
# Workaround pro NVIDIA/open-gpu-kernel-modules#1507: na jádře 7.3+ nv-probe kthread
# neotevře /sys/bus/pci/.../config (kthready běží v nullfs) -> RTD3 "Not supported".
# Rebind z procesního kontextu to opraví. Musí běžet dřív, než kartu kdokoli otevře.
# Odstranit, až to opraví ovladač (zkontroluj: grep 'Runtime D3' /proc/driver/nvidia/gpus/*/power).
for p in /proc/driver/nvidia/gpus/*/power; do
    [ -e "$p" ] || exit 0
    grep -q 'Runtime D3 status: *Not supported' "$p" || continue
    bdf=$(basename "$(dirname "$p")")
    # Nikdo nesmí zařízení držet, jinak unbind visí ("non-zero usage count").
    if fuser -s /dev/nvidia* /dev/dri/by-path/pci-$bdf-* 2>/dev/null; then
        echo "nvidia-rtd3-rebind: $bdf je používáno, přeskakuji"; continue
    fi
    # rmmod, ne modprobe -r: to by odebralo i samotný modul nvidia (nepoužitou závislost)
    # a /sys/bus/pci/drivers/nvidia by zmizel.
    for m in nvidia_drm nvidia_modeset nvidia_uvm; do
        if grep -q "^$m " /proc/modules; then rmmod "$m" || { echo "nelze odebrat $m"; continue 2; }; fi
    done
    echo "$bdf" > /sys/bus/pci/drivers/nvidia/unbind
    echo "$bdf" > /sys/bus/pci/drivers/nvidia/bind
    modprobe nvidia_drm; modprobe nvidia_uvm
    echo "nvidia-rtd3-rebind: $bdf -> $(grep 'Runtime D3' /proc/driver/nvidia/gpus/$bdf/power)"
done
```

### `/etc/systemd/system/nvidia-rtd3-rebind.service`

```ini
[Unit]
Description=Rebind NVIDIA GPU to enable RTD3 (workaround open-gpu-kernel-modules#1507)
After=systemd-modules-load.service systemd-udevd.service
Before=nvidia-powerd.service nvidia-persistenced.service supergfxd.service display-manager.service systemd-user-sessions.service
ConditionPathExists=/sys/bus/pci/drivers/nvidia

[Service]
Type=oneshot
ExecStartPre=/usr/bin/udevadm settle --timeout=30
ExecStart=/usr/local/sbin/nvidia-rtd3-rebind
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable nvidia-rtd3-rebind.service
```

### ⚠️ Poučení (co nedělat)

- **Nikdy nedělat unbind, když kartu někdo drží** (prohlížeč, `nvidia-powerd`, …).
  Zápis do `unbind` pak uvízne v jádře, proces nejde zabít a **systém nejde vypnout**
  (pomůže jen podržet power button ~10 s). Skript to hlídá přes `fuser`.
- **Nepoužívat `modprobe -r nvidia_drm nvidia_modeset nvidia_uvm`** — odebere i modul `nvidia`
  a rebind pak nemá na co sáhnout.
- Ruční test za běhu: `sudo systemctl stop nvidia-powerd`, ověřit, že `sudo lsof /dev/nvidia*`
  je prázdné, pak `sudo /usr/local/sbin/nvidia-rtd3-rebind` a `sudo systemctl start nvidia-powerd`.

### Odstranění (až vyjde opravený ovladač)

```bash
sudo systemctl disable nvidia-rtd3-rebind
sudo rm /etc/systemd/system/nvidia-rtd3-rebind.service /usr/local/sbin/nvidia-rtd3-rebind
sudo systemctl daemon-reload
```

Ponechání nevadí — skript nic nedělá, pokud karta nehlásí „Not supported“.

---

## 7. Aplikace jen na iGPU (aby neprobouzely dGPU)

GTK4 (Vulkan renderer), Firefox/Zen apod. přes glvnd/Vulkan loader otevírají **všechny**
ovladače včetně NVIDIA → `/dev/nvidia*` je otevřené a dGPU se neuspí, i když na ní nic
nevykreslují. Pro konkrétní aplikaci to vyřeší:

```bash
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/radeon_icd.json
export LIBVA_DRIVER_NAME=radeonsi
```

**Nenastavovat globálně** (environment.d, uwsm env) — rozbilo by to `prime-run` pro hry/CUDA.

### Zen Browser — `~/.local/bin/zen-browser` (má v PATH přednost před `/usr/bin`)

```sh
#!/bin/sh
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/radeon_icd.json
export LIBVA_DRIVER_NAME=radeonsi
exec /opt/zen-browser-bin/zen-bin "$@"
```

Pro launchery a otevírání odkazů override `.desktop` souboru:

```bash
sed 's#^Exec=/opt/zen-browser-bin/zen-bin#Exec=$HOME/.local/bin/zen-browser#' \
    /usr/share/applications/zen.desktop > ~/.local/share/applications/zen.desktop
update-desktop-database ~/.local/share/applications
```

Po aktualizaci Zenu, která změní systémový `zen.desktop`, příkaz zopakovat.

### Pango-view poznámky — `poznamka-view.py`

Přímo ve skriptu, **před `import gi`**:

```python
os.environ.setdefault("VK_DRIVER_FILES", "/usr/share/vulkan/icd.d/radeon_icd.json")
os.environ.setdefault("__EGL_VENDOR_LIBRARY_FILENAMES", "/usr/share/glvnd/egl_vendor.d/50_mesa.json")
```

### Spuštění na NVIDIA (hry, CUDA, náročné věci)

```bash
prime-run <program>
```

---

## 8. Ověření

```bash
# Ovladače a moduly
lspci -k | grep -A3 -Ei 'vga|display'
dkms status                                   # nvidia a ostatní "installed" pro aktuální jádro
nvidia-smi

# RTD3 (uspávání dGPU)
grep 'Runtime D3' /proc/driver/nvidia/gpus/*/power        # Enabled (fine-grained)
cat /sys/bus/pci/devices/0000:64:00.0/power/runtime_status # suspended (v klidu)
journalctl -b -u nvidia-rtd3-rebind --no-pager            # výsledek workaroundu při bootu

# Kdo drží dGPU vzhůru (v klidu má být jen nvidia-powerd)
sudo lsof /dev/nvidia* /dev/dri/renderD129 2>/dev/null

# Které NVIDIA knihovny má proces načtené
grep -oE '/[^ ]*nvidia[^ ]*' /proc/<PID>/maps | sort -u

# Mapování DRM karet
for c in /sys/class/drm/card?; do echo "$c -> $(basename $(readlink -f $c/device/driver))"; done
```

Pozn.: `nvidia-smi` dGPU na chvíli probudí — po jeho spuštění chvíli počkat, než bude `suspended`.

---

## 9. Po aktualizaci jádra / ovladače

1. Zkontrolovat výstup pacmanu — `dkms` musí pro nové jádro postavit `nvidia` bez chyby.
2. **Restart je nutný** při změně jádra nebo ovladače NVIDIA.
3. Po restartu spustit kontroly ze sekce 8 (hlavně RTD3).
4. Sledovat [#1507](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1507) —
   jakmile nový ovladač hlásí `Enabled` i bez workaroundu (`journalctl -b -u nvidia-rtd3-rebind`
   nic nevypíše o rebindu), workaround odstranit (sekce 6).
