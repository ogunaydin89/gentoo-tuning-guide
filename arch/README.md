# Arch Linux Tuning Guide: gaming PC

A step-by-step guide to the Arch Linux setup on the gaming PC (Ryzen 7 5800X3D, Radeon RX 9070 XT): the default Arch kernel, the labwc Wayland compositor, Steam, and the tuning carried over from the Gentoo setup this machine used to run.

> **Status: first draft, written during the install.** Steps marked **[unverified]** were written from documentation and from the old Gentoo setup of this machine, and have **not** been run on this Arch install. Items marked **[fill in]** are choices made in the installer that this draft does not know yet. Whoever runs a step (the user or an assistant on the machine) should report the result, and the mark is removed only then.

The Gentoo workstation PC has its own guide in [`../gentoo/`](../gentoo/README.md). The reference files from this machine's old Gentoo install are kept in [`etc-from-gentoo/`](etc-from-gentoo/) as raw material (values, scripts, measured numbers); they are Gentoo/OpenRC files and must be translated, not copied.

## Contents

- [Part 0 – The machine and the installer choices](#part-0--the-machine-and-the-installer-choices)
- [Part 1 – First boot](#part-1--first-boot)
- [Part 2 – labwc desktop](#part-2--labwc-desktop)
- [Part 3 – Kernel and boot](#part-3--kernel-and-boot)
- [Part 4 – System tuning](#part-4--system-tuning)
- [Part 5 – Gaming](#part-5--gaming)
- [Part 6 – Verification](#part-6--verification)
- [Part 7 – Maintenance](#part-7--maintenance)
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
| Disk | [fill in: filesystem and layout] |
| Bootloader | [fill in] |
| Kernel | `linux` (the default Arch kernel) |
| Profile | labwc (brings `alacritty htop labwc nano openssh polkit smartmontools vim wget xdg-utils`) |
| Seat access | polkit (with `systemd-logind`) |
| Greeter | [fill in; `ly` was the suggestion] |
| Graphics driver | AMD / ATI, open source |
| Audio / network | PipeWire / NetworkManager |
| Swap | zram [fill in: compression, `lz4` was the suggestion] |
| Timezone / NTP | Europe/Istanbul, NTP on |

**Additional packages** (the suggestion; check what was actually entered):
```text
waybar fuzzel mako swaybg grim slurp wl-clipboard wlr-randr xorg-xwayland xdg-desktop-portal-wlr xdg-desktop-portal-gtk polkit-gnome network-manager-applet pavucontrol steam lib32-vulkan-radeon git github-cli base-devel btop nvtop usbutils pciutils lm_sensors vulkan-tools zsh fzf zoxide eza bat ripgrep fd fastfetch mpv noto-fonts noto-fonts-emoji ttf-liberation
```
Package names were written from memory of the Arch repositories; the installer rejects a wrong name, and the working list should replace this one. **[unverified]**

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
`curl` comes with `pacman`. `amd-ucode` should be installed by the installer for an AMD CPU; if the second command says it is missing, `sudo pacman -S amd-ucode`, then regenerate the boot configuration for the chosen bootloader. **[unverified]**

---

## Part 2 – labwc desktop

labwc is a wlroots-based stacking compositor in the style of Openbox. After login the screen is empty: it starts no panel, wallpaper or icons itself. A right-click on the desktop opens the root menu (with a terminal entry); `Super+Return` also opens a terminal.

### 2.1 Autostart and keyboard layout

**Do:** `~/.config/labwc/autostart`:
```text
swaybg -c '#1e1e2e' >/dev/null 2>&1 &
waybar >/dev/null 2>&1 &
mako >/dev/null 2>&1 &
nm-applet --indicator >/dev/null 2>&1 &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1 &
```
and `~/.config/labwc/environment`:
```text
XKB_DEFAULT_LAYOUT=tr
```
**Why:** labwc runs the autostart file at login; the file names and the polkit agent path are from documentation and memory. **[unverified]** Check the polkit path with `ls /usr/lib/polkit-gnome/`.

### 2.2 Portals

Screen sharing and file dialogs go through `xdg-desktop-portal`. The `-wlr` backend provides screen casting and screenshots on wlroots compositors; the `-gtk` backend provides file choosers and settings. A preference file, for example `~/.config/xdg-desktop-portal/labwc-portals.conf`:
```ini
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
```
with `XDG_CURRENT_DESKTOP=labwc:wlroots` in the environment file. **[unverified]**

### 2.3 Clipboard

**Verified:** `echo test | wl-copy; wl-paste` prints `test`, so the Wayland clipboard works. Wayland clipboard content belongs to the app that copied it and disappears when that app closes; to keep it, run a clipboard manager from autostart, for example `wl-paste --watch cliphist store &` (needs the `cliphist` package). **[unverified]**

### 2.4 Terminal

labwc's default `Super+Return` launches `lab-sensible-terminal`, which picks the first terminal it finds from a built-in list, and Alacritty comes with the profile. In Alacritty, copy and paste are `Ctrl+Shift+C` and `Ctrl+Shift+V`.

---

## Part 3 – Kernel and boot

The default Arch kernel (`linux`) is used with no custom config: no 1000 Hz tick patches and no fragments. Arch's kernel is a generic desktop kernel; the latency tuning of the Gentoo setup is not carried over.

### 3.1 Kernel command line

**Do:** add to the boot entry's kernel parameters (where depends on the bootloader, **[fill in]**):
```text
amd_pstate=active amdgpu.dcdebugmask=0x10 amdgpu.gpu_recovery=1 amdgpu.ppfeaturemask=0xffffffff
```
**Why** (all measured on this GPU under Gentoo):
- `amd_pstate=active`: the CPU's own frequency control (EPP mode).
- `amdgpu.dcdebugmask=0x10`: fixes desktop freezes on high-refresh monitors (the display engine's power saving cannot ramp up in time for the next frame; symptoms were `flip_done timed out` in `dmesg`).
- `amdgpu.gpu_recovery=1`: reset the GPU instead of hanging when it locks up.
- `amdgpu.ppfeaturemask=0xffffffff`: makes OverDrive (the undervolt, Part 4.4) writable.

Put the amdgpu options only on the command line, not also in `/etc/modprobe.d/`. **[unverified on Arch]**

**Verify:** `cat /proc/cmdline`.

---

## Part 4 – System tuning

All values below come from the old Gentoo setup of this machine ([`etc-from-gentoo/`](etc-from-gentoo/)). The commands to apply them on Arch (systemd) are written from documentation. **[unverified]**

### 4.1 Sysctls

Copy the values from [`etc-from-gentoo/sysctl.d/99-performance.conf`](etc-from-gentoo/sysctl.d/99-performance.conf) to `/etc/sysctl.d/99-performance.conf`: low swappiness for zram, `vm.max_map_count = 2147483642` (some Proton games need it), larger network buffers with BBR, `kernel.split_lock_mitigate = 0` (stops the kernel from slowing programs that do split-lock accesses, which some Unity and older games do constantly) and `vm.compaction_proactiveness = 0`. Apply with `sudo sysctl --system`.

### 4.2 Open-file limit

Steam and Proton (esync) need many file descriptors. On a systemd system raise the limit with a drop-in, for example `/etc/systemd/system.conf.d/limits.conf` and `/etc/systemd/user.conf.d/limits.conf`:
```ini
[Manager]
DefaultLimitNOFILE=524288
```
Verify after re-login with `ulimit -n`.

### 4.3 IPv6, TRIM, time

- **IPv6 off:** the ISP's IPv6 path black-holes large packets (long streaming connections die mid-response). Use [`etc-from-gentoo/sysctl.d/99-disable-ipv6.conf`](etc-from-gentoo/sysctl.d/99-disable-ipv6.conf) and `nmcli con mod "<connection>" ipv6.method disabled`.
- **TRIM:** `sudo systemctl enable --now fstrim.timer`.
- **Time:** the installer's NTP setting enables systemd's time sync; check with `timedatectl`.

### 4.4 GPU undervolt (RX 9070 XT)

Needs `amdgpu.ppfeaturemask=0xffffffff` (Part 3.1). RDNA 4 takes **offsets** from the card's internal maximum (about 3430 MHz here), not absolute clocks: `vo <mV>` for the voltage offset (range -200..0), `s <MHz>` for the clock offset (range -500..+1000; one number, no index; the RDNA 2 form `s 1 <MHz>` fails), then `c` to commit. Measured on this card with a full-screen WebGL shader loop:

| Setting | Peak clock | Avg clock | Power avg / peak | Edge temp |
|---|---|---|---|---|
| -60 mV, no offset | 3307 MHz | 3213 MHz | about 347 W (power limit) | 48 °C |
| -100 mV, -407 MHz | 3023 MHz | 2970 MHz | 207 / 244 W | 49 °C |
| **-100 mV, -500 MHz (daily)** | **2932 MHz** | **2882 MHz** | **236 / 276 W** | 52 °C |

-500 MHz is the driver's lower limit, so about 2930 MHz is the lowest reachable cap: roughly 10 % less clock for about 110 W less power. If a game crashes or `dmesg` shows `ring … timeout` or `GPU reset`, go back to `vo -80` first and keep `s -500`. The old OpenRC script is [`etc-from-gentoo/local.d/amdgpu-undervolt.start`](etc-from-gentoo/local.d/amdgpu-undervolt.start); on Arch run the same writes from a systemd oneshot service ordered after the GPU is up. It also sets the `3D_FULL_SCREEN` power profile (`pp_power_profile_mode` = 1) for faster clock ramp-up in games. **[unverified]**

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
- **NTSYNC:** recent Wine/Proton can use `/dev/ntsync`. Check with `sudo modprobe ntsync` and `ls -l /dev/ntsync`; if the module exists, load it at boot with a file in `/etc/modules-load.d/`. **[unverified on Arch]**
- **VRR (adaptive sync):** the monitor supports 48–240 Hz. With KDE Plasma it was kept off because it now and then broke games; with labwc it is a compositor option whose behaviour is **[unverified]**.
- **PipeWire latency:** [`etc-from-gentoo/pipewire/pipewire.conf.d/10-latency.conf`](etc-from-gentoo/pipewire/pipewire.conf.d/10-latency.conf) sets a 64/32 sample quantum at 48 kHz (about 1.3 ms). **[unverified]**

---

## Part 6 – Verification

| Check | Command | Expected |
|---|---|---|
| Kernel line | `cat /proc/cmdline` | `amd_pstate=active … amdgpu.ppfeaturemask=0xffffffff` |
| GPU driver | `vulkaninfo --summary \| grep driverName` | `radv` |
| Undervolt | `cat /sys/class/drm/card*/device/pp_od_clk_voltage` | the voltage and clock offsets |
| Swap | `swapon --show` | the zram device |
| Sysctls | `sysctl vm.swappiness kernel.split_lock_mitigate` | `10`, `0` |
| File limit | `ulimit -n` | `524288` |
| Clipboard | `echo test \| wl-copy; wl-paste` | `test` |
| Updates | `sudo pacman -Syu` | `there is nothing to do` |

---

## Part 7 – Maintenance

- **Update:** `sudo pacman -Syu` regularly. Never do a partial upgrade (`pacman -Sy` followed by installing a package).
- **Config updates:** after an update, look for `.pacnew` files with `sudo find /etc -name '*.pacnew'` (or `pacdiff` from `pacman-contrib`) and merge them by hand. Never overwrite your own files blindly.
- **Cache:** `sudo paccache -d` lists old cached packages that can be removed (`pacman-contrib`).
- **Orphans:** `pacman -Qdtq` lists packages nothing needs; review before removing.
- **Mirrors:** run the `reflector` command from Part 1.1 when downloads get slow.
- **AUR:** nothing in this setup needs it for now. A helper such as `paru` would only be needed for something like `ryzen_smu` (CPU monitoring), and AUR recipes should be read before building.

---

## Appendix – Known quirks

- **An empty screen after logging in to labwc is normal.** The desktop has to be assembled (Part 2). A right-click opens the root menu; Ctrl+Alt+F3 gives a text login if needed.
- **A command or token copied on another computer cannot be pasted on this one.** A clipboard never leaves the machine. Do the paste from the other machine over SSH (`openssh` is installed; enable `sshd` only while needed).
- **Pasting into agy's terminal interface may fail with Ctrl+Shift+V** (a TUI that mishandles bracketed paste). Alternatives: `Shift+Insert`, middle-click, or typing the clipboard in with `wtype`: `sleep 4; wl-paste | wtype -`. **[unverified which one works]**
- **Drag-selecting inside a terminal program that captures the mouse** needs `Shift` held down in Alacritty.
- **Where is Konsole?** It is not part of the labwc profile; labwc uses Alacritty.

## License

This guide is licensed under [CC BY 4.0](../LICENSE) © Ogün Aydın: free to use, share and adapt, with credit.
