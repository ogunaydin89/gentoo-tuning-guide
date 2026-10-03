# Arch Linux Tuning Guide: gaming PC

A step-by-step guide to the Arch Linux setup on the gaming PC (Ryzen 7 5800X3D, Radeon RX 9070 XT): the default Arch kernel, KDE Plasma on Wayland, Steam, and the tuning carried over from the Gentoo setup this machine used to run.

> **Status: rewritten for KDE Plasma, to be verified on a fresh install.** The system tuning (Parts 3–5) was verified on this machine's earlier Arch install, which ran labwc; the KDE parts (Part 2, the package list, the installer profile) are written from documentation and are **[unverified]**. Ready-to-copy template files are in [`etc/`](etc/), [`home/`](home/) and [`usr/`](usr/). Items marked **[fill in]** are installer choices not known yet. Whoever runs a step (the user or an assistant on the machine) should report the result, and a mark is removed only then.

The Gentoo workstation PC has its own guide in [`../gentoo/`](../gentoo/README.md). The reference files from this machine's old Gentoo install are kept in [`etc-from-gentoo/`](etc-from-gentoo/) as raw material (values, scripts, measured numbers); they are Gentoo/OpenRC files and must be translated, not copied.

## Contents

- [Part 0 – The machine and the installer choices](#part-0--the-machine-and-the-installer-choices)
- [Part 1 – First boot](#part-1--first-boot)
- [Part 2 – KDE Plasma desktop](#part-2--kde-plasma-desktop)
- [Part 3 – Kernel and boot](#part-3--kernel-and-boot)
- [Part 4 – System tuning](#part-4--system-tuning)
- [Part 5 – Gaming](#part-5--gaming)
- [Part 6 – Verification](#part-6--verification)
- [Part 7 – Maintenance](#part-7--maintenance)
- [Decisions and why](#decisions-and-why)
- [Appendix – Known quirks](#appendix--known-quirks)

---

## Part 0 – The machine and the installer choices

| | |
|---|---|
| CPU | Ryzen 7 5800X3D (8c/16t, 96 MB V-Cache, locked multiplier) |
| GPU | Sapphire Nitro+ RX 9070 XT (RDNA 4, Navi 48) |
| RAM | 32 GB DDR4-3200 CL16 (2× Kingston Fury KF3200C16D4/16GX) |
| Board | MSI MPG B550 GAMING PLUS (Super I/O Nuvoton NCT6687D); PBO and Curve Optimizer available in the BIOS |
| Monitor | 1080p IPS with adaptive sync (48–240 Hz) |
| Role | gaming only; no browser, no mining |

### archinstall choices

| Menu | Choice |
|---|---|
| Locale | language `en_GB.UTF-8`, keyboard layout `trq` (Turkish Q) |
| Mirrors | Turkey and Germany; `reflector` added as an extra package |
| Optional repositories | `multilib` (needed by Steam and 32-bit graphics libraries) |
| Disk | `ext4` on `/` (`/dev/nvme0n1p2`, 425 GB), `FAT32` on `/boot` (`/dev/nvme0n1p1`, 1 GB ESP) |
| Bootloader | systemd-boot with UKI (`/boot/EFI/Linux/arch-linux.efi`) |
| Kernel | `linux` (the default Arch kernel) |
| Profile | KDE Plasma (the profile brings Plasma, Konsole, Dolphin and more; **[fill in]** the exact package list after the install) |
| Seat access | polkit (with `systemd-logind`) |
| Greeter | `sddm` (enabled by the Plasma profile) |
| Graphics driver | AMD / ATI, open source (`amdgpu`, `vulkan-radeon`) |
| Audio / network | PipeWire / NetworkManager |
| Swap | zram (`/dev/zram0`, 31.3 GB, `lz4`, priority 100) |
| Timezone / NTP | Europe/Istanbul, NTP on |

### Package list

Every package this guide needs, by group. The archinstall profile and menu choices install most of the base and desktop groups; the **Install everything** command below is safe to run afterwards because `--needed` skips what is already installed. Groups marked **[unverified]** have not been run on the fresh KDE install; the rest was installed and verified on the earlier install.

| Group | Packages |
|---|---|
| Base and boot | `base` `linux` `linux-firmware` `amd-ucode` `base-devel` `git` `github-cli` `openssh` `reflector` `pacman-contrib` `zram-generator` `smartmontools` `xdg-utils` `nano` `vim` `wget` |
| Graphics and Vulkan | `mesa` `vulkan-radeon` `lib32-mesa` `lib32-vulkan-radeon` `vulkan-tools` `xorg-xwayland` |
| KDE Plasma desktop **[unverified]** | `plasma-meta` `sddm` `konsole` `dolphin` `kate` `ark` `okular` `gwenview` `wl-clipboard` |
| Audio and network | `pipewire` `pipewire-alsa` `pipewire-pulse` `wireplumber` `rtkit` `networkmanager` |
| Gaming | `steam` |
| Monitoring and hardware tools | `btop` `nvtop` `usbutils` `pciutils` `lm_sensors` |
| Shell and command-line tools | `zsh` `zsh-syntax-highlighting` `fzf` `zoxide` `eza` `bat` `ripgrep` `fd` `fastfetch` `mpv` |
| Fonts | `noto-fonts` `noto-fonts-emoji` `ttf-liberation` `otf-font-awesome` `ttf-nerd-fonts-symbols` `ttf-nerd-fonts-symbols-mono` `ttf-jetbrains-mono-nerd` |

**Install everything** (after `multilib` is enabled in `/etc/pacman.conf`; `--needed` skips what is installed, `-S` installs from the repositories):
```bash
sudo pacman -S --needed base linux linux-firmware amd-ucode base-devel git github-cli openssh reflector pacman-contrib zram-generator smartmontools xdg-utils nano vim wget \
  mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon vulkan-tools xorg-xwayland \
  plasma-meta sddm konsole dolphin kate ark okular gwenview wl-clipboard \
  pipewire pipewire-alsa pipewire-pulse wireplumber rtkit networkmanager \
  steam btop nvtop usbutils pciutils lm_sensors \
  zsh zsh-syntax-highlighting fzf zoxide eza bat ripgrep fd fastfetch mpv \
  noto-fonts noto-fonts-emoji ttf-liberation otf-font-awesome ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono ttf-jetbrains-mono-nerd
```
`ttf-nerd-fonts-symbols`, `ttf-jetbrains-mono-nerd` and the rest come from `extra`; `steam` and the `lib32-*` packages come from `multilib`. `zsh-syntax-highlighting` is needed by [`../common/home/.zshrc`](../common/home/.zshrc). No AUR packages are used.

---

## Part 1 – First boot

### 1.1 Update the system

**Do:**
```bash
sudo reflector --country Turkey,Germany --protocol https --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syyu
```
**Why:** `reflector` ranks the mirrors by real speed and `--save` writes them to the mirror list (plain `reflector` only prints). `-Syyu` force-refreshes the package databases after the mirror change and updates everything; `-uu` (downgrades) is only needed when the new mirrors are older than the old ones, which `--latest 20` avoids.

**Verify:** `sudo pacman -Syu` reports `there is nothing to do`.

### 1.2 Check the base

```bash
command -v curl wget git Xwayland
pacman -Qq amd-ucode
```
`curl` comes with `pacman`. `amd-ucode` is installed and microcode loading is verified in initcpio.

---

## Part 2 – KDE Plasma desktop

KDE Plasma 6 runs on Wayland by default and brings its own panel, notifications, network and audio widgets, clipboard manager (Klipper), polkit agent and portals, so this part is short. **All of Part 2 is [unverified] on this machine until the fresh KDE install has been run through.**

### 2.1 Install and enable

**Do:** choose the *KDE Plasma* profile in `archinstall` (it installs Plasma, SDDM, Konsole and Dolphin and enables the display manager). If Plasma is added to an existing system instead:
```bash
sudo pacman -S --needed plasma-meta konsole dolphin kate ark okular gwenview
sudo systemctl enable sddm.service
```
**Why:** `plasma-meta` pulls the whole desktop (KWin, the panel, System Settings, `plasma-nm`, `plasma-pa`, `powerdevil`, `xdg-desktop-portal-kde`, the polkit agent). `--needed` skips packages that are already installed. The enabled `sddm.service` shows the graphical login.

**Verify:** after login `echo $XDG_SESSION_TYPE` prints `wayland`, and `pacman -Q plasma-meta` shows the package.

### 2.2 Keyboard layout

The installer's `trq` layout covers the text console. For Plasma set the layout in *System Settings → Keyboard → Layouts* (Turkish, Q), and for the SDDM login screen in *System Settings → Login Screen (SDDM)* or with `localectl set-x11-keymap tr`.

**Verify:** `localectl status` shows `X11 Layout: tr`.

### 2.3 Portals, polkit and clipboard

Nothing to configure. `xdg-desktop-portal-kde` provides file dialogs, screen casting and screenshots, the Plasma polkit agent shows the permission prompts, and Klipper keeps clipboard history (it keeps content after the source app closes). `wl-clipboard` stays installed for scripts: `echo test | wl-copy; wl-paste` should print `test`.

### 2.4 Terminal

Konsole is the terminal (`Ctrl+Alt+T` opens it). Copy and paste are `Ctrl+Shift+C` and `Ctrl+Shift+V`. The shell setup in [`../common/`](../common/) is written for Konsole's key codes.

---

## Part 3 – Kernel and boot

The default Arch kernel (`linux`) ships natively with `CONFIG_HZ=1000` and `CONFIG_NO_HZ_FULL=y`, providing 1 ms scheduling latency out of the box.

### 3.1 Kernel command line

**Do:** add to the kernel parameters:
```text
amd_pstate=active amdgpu.dcdebugmask=0x10 amdgpu.gpu_recovery=1 amdgpu.ppfeaturemask=0xffffffff transparent_hugepage=madvise
```
**Why** (all measured on this GPU under Gentoo):
- `amd_pstate=active`: the CPU's own frequency control (EPP mode).
- `amdgpu.dcdebugmask=0x10`: fixes desktop freezes on high-refresh monitors (the display engine's power saving cannot ramp up in time for the next frame; symptoms were `flip_done timed out` in `dmesg`).
- `amdgpu.gpu_recovery=1`: reset the GPU instead of hanging when it locks up.
- `amdgpu.ppfeaturemask=0xffffffff`: makes OverDrive (the undervolt, Part 4.4) writable.
- `transparent_hugepage=madvise`: huge pages only where programs ask for them, preventing memory compaction stalls and micro-stutter in games.

This machine uses **systemd-boot with a Unified Kernel Image (UKI)** (`/boot/EFI/Linux/arch-linux.efi`):
1. Append the parameters to `/etc/kernel/cmdline`.
2. Regenerate the UKI with `sudo mkinitcpio -P`.

Put the amdgpu options only on the command line, not also in `/etc/modprobe.d/`.

**Verify:** `cat /proc/cmdline`.

---

## Part 4 – System tuning

All values below come from the old Gentoo setup of this machine ([`etc-from-gentoo/`](etc-from-gentoo/), kept as raw material). The ready-to-copy Arch (systemd) versions are the template files in this folder; each one starts with an "Install to …" line. From the repository folder `arch/`:
```bash
sudo install -Dm644 etc/sysctl.d/99-performance.conf /etc/sysctl.d/99-performance.conf
sudo install -Dm644 etc/sysctl.d/99-disable-ipv6.conf /etc/sysctl.d/99-disable-ipv6.conf
sudo install -Dm644 etc/systemd/system.conf.d/limits.conf /etc/systemd/system.conf.d/limits.conf
sudo install -Dm644 etc/systemd/user.conf.d/limits.conf /etc/systemd/user.conf.d/limits.conf
sudo install -Dm644 etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf
sudo install -Dm755 usr/local/bin/amdgpu-undervolt.sh /usr/local/bin/amdgpu-undervolt.sh
sudo install -Dm644 etc/systemd/system/amdgpu-undervolt.service /etc/systemd/system/amdgpu-undervolt.service
sudo install -Dm644 etc/tmpfiles.d/cpu-epp.conf /etc/tmpfiles.d/cpu-epp.conf
sudo install -Dm644 etc/tmpfiles.d/thp.conf /etc/tmpfiles.d/thp.conf
sudo sysctl --system && sudo systemctl daemon-reload && sudo systemd-tmpfiles --create && sudo systemctl enable --now amdgpu-undervolt.service
```
- **`install -Dm644 src dest`** copies the file, creates missing parent folders (`-D`) and sets the mode (`-m644` for configs, `-m755` for the script).
- **Desktop files** (PipeWire) are user files: copy `home/.config/…` into `~/.config/…`.
- **`zram-generator`:** the installer's zram option may already have written `/etc/systemd/zram-generator.conf`; keep one file only.
- **`ntsync.conf`:** install it only if `sudo modprobe ntsync` works and `/dev/ntsync` appears.

All of these were verified on the earlier install (Part 6); after the fresh KDE install, re-run the Part 6 checks.

### 4.1 Sysctls

Copy the values from [`etc/sysctl.d/99-performance.conf`](etc/sysctl.d/99-performance.conf) to `/etc/sysctl.d/99-performance.conf`: low swappiness for zram, `vm.max_map_count = 2147483642` (some Proton games need it), larger network buffers with BBR, `kernel.split_lock_mitigate = 0` (stops the kernel from slowing programs that do split-lock accesses, which some Unity and older games do constantly) and `vm.compaction_proactiveness = 0`. Apply with `sudo sysctl --system`.

### 4.2 Open-file limit

Steam and Proton (esync) need many file descriptors. On a systemd system raise the limit with a drop-in, for example `/etc/systemd/system.conf.d/limits.conf` and `/etc/systemd/user.conf.d/limits.conf`:
```ini
[Manager]
DefaultLimitNOFILE=524288
```
Verify after re-login with `ulimit -n`.

### 4.3 IPv6, TRIM, time

- **IPv6 off:** the ISP's IPv6 path black-holes large packets (long streaming connections die mid-response). Use [`etc/sysctl.d/99-disable-ipv6.conf`](etc/sysctl.d/99-disable-ipv6.conf) and `nmcli con mod "<connection>" ipv6.method disabled`.
- **Filesystem (noatime):** root NVMe partition mounted with `noatime` in [`etc/fstab`](etc/fstab) to avoid metadata write cycles on game asset reads.
- **TRIM:** `sudo systemctl enable --now fstrim.timer`.
- **Time:** the installer's NTP setting enables systemd's time sync; check with `timedatectl`.

### 4.4 GPU undervolt (RX 9070 XT)

Needs `amdgpu.ppfeaturemask=0xffffffff` (Part 3.1). RDNA 4 takes **offsets** from the card's internal maximum (about 3430 MHz here), not absolute clocks: `vo <mV>` for the voltage offset (range -200..0), `s <MHz>` for the clock offset (range -500..+1000; one number, no index; the RDNA 2 form `s 1 <MHz>` fails), then `c` to commit. Measured on this card with a full-screen WebGL shader loop:

| Setting | Peak clock | Avg clock | Power avg / peak | Edge temp |
|---|---|---|---|---|
| -60 mV, no offset | 3307 MHz | 3213 MHz | about 347 W (power limit) | 48 °C |
| -100 mV, -407 MHz | 3023 MHz | 2970 MHz | 207 / 244 W | 49 °C |
| **-100 mV, -500 MHz (daily)** | **2932 MHz** | **2882 MHz** | **236 / 276 W** | 52 °C |

-500 MHz is the driver's lower limit, so about 2930 MHz is the lowest reachable cap: roughly 10 % less clock for about 110 W less power. If a game crashes or `dmesg` shows `ring … timeout` or `GPU reset`, go back to `vo -80` first and keep `s -500`. On Arch, the writes run from the systemd oneshot service [`etc/systemd/system/amdgpu-undervolt.service`](etc/systemd/system/amdgpu-undervolt.service) and [`usr/local/bin/amdgpu-undervolt.sh`](usr/local/bin/amdgpu-undervolt.sh). It also sets the `3D_FULL_SCREEN` power profile (`pp_power_profile_mode` = 1) for faster clock ramp-up in games. Verified running on boot.

### 4.5 CPU (BIOS)

The 5800X3D's multiplier is locked; the real tuning is Curve Optimizer (per-core voltage and frequency curve, in the BIOS under *PBO → Curve Optimizer*, AGESA 1.2.0.8 or later). Settings that were stable on this chip, matched to its CPPC ranking:

| PBO limit | Value |
|---|---|
| PPT / TDC / EDC / THM | 142 W / 95 A / 130 A / 90 °C |

| Core | CPPC | CO |
|---|---|---|
| 0, 1, 2 | 196, 196, 191 | -20 |
| 5, 4, 3 | 186, 181, 176 | -25 |
| 6, 7 | 171, 166 | -30 |

The best cores get the mildest offset: they boost highest and become unstable first. Curve Optimizer instability shows at light single-core loads (idle, browsing), not in all-core loads; if random reboots happen at idle, back off cores 6 and 7 to -25 first. Memory: DDR4-3200 CL16-20-20-39 1T with FCLK = UCLK = MCLK = 1600 MHz (1:1), the kit's rated XMP profile. BIOS settings survive the OS reinstall. CO values cannot be read reliably from Linux; check them in the BIOS.

---

## Part 5 – Gaming

- **Steam:** `steam` from `multilib`, with `lib32-vulkan-radeon` for 32-bit games. Steam and most games run through Xwayland, so `xorg-xwayland` must be installed.
- **No layers:** plain Steam, no gamemode, MangoHud or gamescope. The CPU is already on the `performance` energy preference.
- **NTSYNC:** recent Wine/Proton can use `/dev/ntsync`. Verified with `sudo modprobe ntsync` and `ls -l /dev/ntsync`; loaded at boot via `/etc/modules-load.d/ntsync.conf`.
- **PipeWire latency:** [`home/.config/pipewire/pipewire.conf.d/10-latency.conf`](home/.config/pipewire/pipewire.conf.d/10-latency.conf) sets a 64/32 sample quantum at 48 kHz (about 1.3 ms), verified via `pw-metadata`.
- **Audio scheduling:** `rtkit` (RealtimeKit) daemon enabled for PipeWire / WirePlumber to guarantee realtime priority without dropouts under gaming load.

---

## Part 6 – Verification

| Check | Command | Expected / Verified |
|---|---|---|
| Kernel line | `cat /proc/cmdline` | `amd_pstate=active … transparent_hugepage=madvise` (verified) |
| GPU driver | `vulkaninfo --summary \| grep driverName` | `driverName = radv` (verified) |
| Undervolt | `cat /sys/class/drm/card*/device/pp_od_clk_voltage` | `OD_SCLK_OFFSET: -500Mhz`, `OD_VDDGFX_OFFSET: -100mV` (verified) |
| Power profile | `cat /sys/class/drm/card*/device/pp_power_profile_mode` | `1 3D_FULL_SCREEN*` (verified) |
| Swap | `swapon --show` | `/dev/zram0 partition 31.3G (lz4, prio 100)` (verified) |
| Sysctls | `sysctl vm.swappiness kernel.split_lock_mitigate` | `10`, `0` (verified) |
| THP mode | `cat /sys/kernel/mm/transparent_hugepage/enabled` | `always [madvise] never` (verified) |
| CPU EPP | `cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference` | `performance` (verified) |
| File limit | `ulimit -n` | `524288` (verified) |
| NTSYNC | `ls -l /dev/ntsync` | `/dev/ntsync` (verified) |
| PipeWire latency | `pw-metadata -n settings 0` | `clock.quantum = 64` (verified) |
| RTKit daemon | `systemctl is-active rtkit-daemon` | `active` (verified) |
| Filesystem mount | `findmnt -no OPTIONS /` | `rw,noatime` (verified) |
| Clipboard | `echo test \| wl-copy; wl-paste` | `test` (verified on the earlier labwc install; re-check under Plasma) |
| Updates | `sudo pacman -Syu` | `there is nothing to do` (verified) |

---

## Part 7 – Maintenance

- **Update:** `sudo pacman -Syu` regularly. Never do a partial upgrade (`pacman -Sy` followed by installing a package).
- **Config updates:** after an update, look for `.pacnew` files with `sudo find /etc -name '*.pacnew'` (or `pacdiff` from `pacman-contrib`) and merge them by hand. Never overwrite your own files blindly.
- **Cache:** `sudo paccache -d` lists old cached packages that can be removed (`pacman-contrib`).
- **Orphans:** `pacman -Qdtq` lists packages nothing needs; review before removing.
- **Mirrors:** run the `reflector` command from Part 1.1 when downloads get slow.
- **AUR and other third-party sources:** avoided. Official repositories (`core`, `extra`, `multilib`) only, unless there is no other way; in that case read the PKGBUILD first and tell the user. No Flatpak or Snap either.

---

## Decisions and why

- **Arch instead of Gentoo on this PC.** A gaming machine mostly wants fresh drivers (the RX 9070 XT needs a recent kernel and Mesa) and quick updates, not a multi-hour compile after every update. Gentoo stays on the workstation PC, where compile control pays off.
- **The default `linux` kernel.** No custom config, no per-machine kernel to maintain. The Gentoo kernel's latency tuning (1000 Hz tick, full preemption) is deliberately not carried over.
- **KDE Plasma instead of a minimal compositor.** Plasma 6 is the most common desktop on Arch, has working Wayland, a built-in clipboard manager, notifications, network and audio widgets, and screen sharing out of the box, so nothing has to be assembled by hand. The machine briefly ran labwc and the manual setup was not worth the effort. The cost is a few hundred MB more RAM, which a 32 GB gaming PC does not miss.
- **polkit and `systemd-logind`.** `systemd-logind` already provides seats and sessions; polkit adds the permission prompts for mounting drives, network changes and power actions, and Plasma ships its own polkit agent.
- **No browser on this PC.** Browsing happens on the workstation PC, and Steam has its own web view. If one is ever needed, `firefox` or `chromium` come from the official repositories.
- **Official repositories only, where possible.** Nothing in this setup needs the AUR, Flatpak or Snap. A third-party source would be used only when there is no other way, after the user agrees and the build recipe has been read.
- **No hugepages and no MSR tweaks.** The gain was measured at about 3 % on the workstation PC and the risk of a broken desktop is not worth it. This applies to mining as well as to the kernel.
- **zram with `lz4`.** The CPU-cheapest algorithm; with 32 GB of RAM zram is rarely full, so low CPU cost matters more than compression ratio.
- **Terminal:** Konsole comes with the Plasma profile (`Ctrl+Alt+T`).

---

## Appendix – Known quirks

- **Plasma starts on Wayland, with SDDM on X11 or Wayland.** If a game or screen-sharing app misbehaves, check the session type with `echo $XDG_SESSION_TYPE` (expected: `wayland`).
- **A command or token copied on another computer cannot be pasted on this one.** A clipboard never leaves the machine. Do the paste from the other machine over SSH (`openssh` is installed; enable `sshd` only while needed).
- **Pasting into agy's terminal interface may fail with Ctrl+Shift+V** (a TUI that mishandles bracketed paste). Alternatives: `Shift+Insert`, middle-click, or typing the clipboard in with `wtype`: `sleep 4; wl-paste | wtype -`. **[unverified which one works]**
- **Where are the terminal and file manager?** Konsole (`Ctrl+Alt+T`) and Dolphin come with the Plasma profile. In Konsole, copy and paste are `Ctrl+Shift+C` and `Ctrl+Shift+V`.

## License

This guide is licensed under [CC BY 4.0](../LICENSE) © Ogün Aydın: free to use, share and adapt, with credit.
