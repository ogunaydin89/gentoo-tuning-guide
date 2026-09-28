# Gentoo Tuning Guide

A step-by-step guide to the Gentoo setup used on a small fleet of AMD Ryzen + Radeon machines: low-latency kernel, gaming tuning, a home binhost, and the maintenance routine that keeps it all working. Everything here is verified on real hardware; the reference files for each machine are in [`etc/`](etc/) and [`home/`](home/).

```bash
git clone https://github.com/ogunaydin89/gentoo-tuning-guide.git
```

## Contents

- [Part 0 – Before you start](#part-0--before-you-start)
- [Part 1 – Portage foundation](#part-1--portage-foundation)
- [Part 2 – Toolchain and core tools](#part-2--toolchain-and-core-tools)
- [Part 3 – Kernel and boot](#part-3--kernel-and-boot)
- [Part 4 – System tuning and services](#part-4--system-tuning-and-services)
- [Part 5 – Desktop and software](#part-5--desktop-and-software)
- [Part 6 – Final verification](#part-6--final-verification)
- [Part 7 – Maintenance](#part-7--maintenance)
- [Appendix A – Home binhost (Frankenstein)](#appendix-a--home-binhost-frankenstein)
- [Appendix B – Pitfalls](#appendix-b--pitfalls)
- [Appendix C – AI / ROCm reference](#appendix-c--ai--rocm-reference)
- [Appendix D – Policies](#appendix-d--policies)

---

## Part 0 – Before you start

### Machines

| | Battleship (main gaming) | Frankenstein (workhorse, binhost) |
|---|---|---|
| CPU | Ryzen 7 5800X3D (8c/16t, 96 MB V-Cache) | Ryzen 7 5700X (8c/16t) |
| GPU | Sapphire Nitro+ RX 9070 XT (RDNA 4, Navi 48) | RX 6650 XT (RDNA 2, Navi 23) |
| RAM | 32 GB DDR4-3200 CL16 (2× Kingston Fury KF3200C16D4/16GX) | 16 GB DDR4-3600 |
| Board | MSI MPG B550 GAMING PLUS (Super I/O NCT6687D) | A520M-HDV (Super I/O NCT6793D) |
| Kernel suffix | `-5800x3dv9070xt` | `-5700v6650` |
| Role | binhost **client** | compiles and serves binaries |
| Reference files | [`etc/battleship/`](etc/battleship/) | [`etc/frankenstein/`](etc/frankenstein/) |

Both: Gentoo, profile `default/linux/amd64/23.0/desktop/plasma`, OpenRC, KDE Plasma 6 on Wayland, PipeWire, global `~amd64`, CPU target `znver3`. (A third machine, a school office PC with a Ryzen 5 5600G and GTX 1650, runs Windows 11; nothing here applies to it.)

### What this guide assumes

- A booting Gentoo stage3 install with the `desktop/plasma` OpenRC profile, a user in `wheel`, network working.
- UEFI boot with the EFI system partition mounted at `/boot`.

### How steps are written

Each step has **Do** (what to change), **Why**, and **Verify** (a command and the expected result). Do the parts in order: later parts rely on earlier ones. Reboot points are marked **[reboot]**.

Machine-specific values are given for both machines, or the step says which machine it is for. Copy files from `etc/<machine>/` only after reading them; never copy one machine's hardware values (sensor chip, undervolt, kernel suffix) to the other.

### Naming: `CPUvGPU`

Every kernel carries the machine's CPU and GPU in its release name via `CONFIG_LOCALVERSION`, e.g. `uname -r` → `7.2.8-5800x3dv9070xt`. It makes it obvious which config a kernel was built with.

### For AI assistants working on a different machine

- Detect the hardware first: `lscpu`, `cpuid2cpuflags`, `lspci -k | grep -EA3 "VGA|3D"`, `free -h`. Adapt `CPU_FLAGS_X86`, `VIDEO_CARDS`, the Super I/O sensor driver, `CONFIG_LOCALVERSION`, zram and tmpfs sizes.
- **Never carry a GPU undervolt from one card to another.** Voltage/frequency behaviour differs per GPU generation and per chip. Research the exact card, then measure (Part 4.12).
- Binary packages come only from the home binhost (Appendix A), never from Gentoo's official binhost.
- Ask the user before any system change, and before committing or pushing to this repository.

---

## Part 1 – Portage foundation

Small configuration only. The point of this part is that everything installed later is built once, with the right flags, and (on the Battleship) arrives as a binary from the home binhost.

### 1.1 Git sync and the Steam overlay

**Do:** `/etc/portage/repos.conf/gentoo.conf` ([battleship](etc/battleship/portage/repos.conf/gentoo.conf)):
```ini
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = git
sync-uri = https://github.com/gentoo-mirror/gentoo.git
auto-sync = yes
sync-depth = 1
```
Then:
```bash
sudo emerge -1 dev-vcs/git app-eselect/eselect-repository
sudo rm -rf /var/db/repos/gentoo && sudo emaint sync -r gentoo
sudo eselect repository enable steam-overlay
sudo emaint sync -a
```

**Why:** the `gentoo-mirror` repository is the "sync friendly" git mirror: it includes news, GLSAs and metadata, and Portage verifies it (the 2025-11 news item about git verification only affects the raw repository). A git sync takes seconds. `steam-overlay` provides `games-util/steam-launcher`.

**Verify:** `eselect repository list -i` shows `gentoo` and `steam-overlay`.

### 1.2 `make.conf` base

**Do:** start from [`etc/battleship/portage/make.conf`](etc/battleship/portage/make.conf), **but leave these out for now** (Part 2 adds them once the tools exist):

- `-fuse-ld=mold` in `LDFLAGS` and `RUSTFLAGS`: every link fails until mold is installed.
- `ccache` in `FEATURES` and `CCACHE_DIR`: needs ccache installed.
- `CPU_FLAGS_X86`: generated in Part 2.

The rest:
```bash
COMMON_FLAGS="-O2 -march=native -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
LDFLAGS="${COMMON_FLAGS} -Wl,-O1 -Wl,--as-needed"

MAKEOPTS="-j16 -l14"
NINJAOPTS="-j16"
EMERGE_DEFAULT_OPTS="--jobs=16 --load-average=14"

ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"

GRUB_PLATFORMS="efi-64"
VIDEO_CARDS="amdgpu radeonsi"

USE="wayland pipewire pipewire-alsa elogind dbus udev policykit lz4 zstd pulseaudio alsa vulkan opengl vdpau vaapi hwaccel screencast networkmanager sddm plasma dav1d svt-av1 jpegxl avif heif opus x264 x265 -systemd -telemetry -bluetooth -cups -modemmanager -handbook -doc -test"

FEATURES="parallel-fetch parallel-install"
LC_MESSAGES=C.utf8
BINPKG_COMPRESS="lz4"
BINPKG_COMPRESS_FLAGS="-T16"
PORTAGE_COMPRESS="lz4"
PORTAGE_COMPRESS_FLAGS="-T16"
```

**Why:**
- `-march=native` builds for the machine's own CPU (both resolve to `znver3`). Binaries from Frankenstein work on the Battleship because both are Zen 3 with the same instruction set.
- `-j16 -l14`: 16 threads, but stop starting jobs when the load passes 14 so the desktop stays responsive.
- **Global `~amd64`:** everything tracks testing together. Mixing stable and testing leads to version skew between runtimes and their virtuals, long backtracking, and a pile of keyword files. With global `~amd64`, `package.accept_keywords/` stays empty.
- `ACCEPT_LICENSE="*"` accepts all licenses, so no `package.license` file is needed (e.g. for Chrome).
- The USE line drops Bluetooth, printing, modems, systemd and docs. CUPS still gets installed as a library because Chrome, GTK and Qt require it; no printing service runs.
- `wireplumber` and `zram` are **not** USE flags; do not add them (they do nothing).

**Verify:** `emerge --info | grep -E '^(CFLAGS|USE|ACCEPT_KEYWORDS)='`.

### 1.3 Build directory in RAM

**Do:** add to `/etc/fstab`, then `sudo mount /var/tmp/portage`:
```
tmpfs   /var/tmp/portage   tmpfs   size=28G,uid=portage,gid=portage,mode=775,noatime   0 0
```
Size: 28G on 32 GB RAM (Battleship), 24G on 16 GB (Frankenstein). A tmpfs only uses RAM for what is in it; zram (Part 4.3) absorbs the peaks.

**Why:** compiling in RAM is faster and saves SSD writes.

**Verify:** `findmnt /var/tmp/portage` → `tmpfs`.

### 1.4 All `package.use` settings up front

**Do:** copy [`etc/battleship/portage/package.use/`](etc/battleship/portage/package.use/) to `/etc/portage/package.use/`:

| File | Content | Why |
|---|---|---|
| `00-installkernel.conf` | `sys-kernel/installkernel dracut grub` | builds the initramfs and updates GRUB on every kernel install |
| `00-kernel.conf` | `sys-kernel/gentoo-kernel -debug` | no debug symbols (much smaller, faster build) |
| `01-desktop.conf` | `pipewire sound-server`, `mesa vulkan vaapi`, `minizip-ng compat`, `libdrm video_cards_radeon`, `qtbase cups` | desktop audio, Mesa video features; `libdrm[video_cards_radeon]` is required by radeonsi; `minizip-ng compat` is needed by `virtual/minizip` |
| `02-fixes.conf` | `pillow -truetype`, `zlib -minizip`, `ncurses -gpm` | dependency-cycle and conflict fixes; `ncurses -gpm` breaks the 32-bit ncurses ↔ gpm cycle (gpm is console mouse only) |
| `10-modules` | `app-admin/ryzen_smu dist-kernel` | rebuilds the module automatically for every new kernel |
| `desktop.conf` | `kde-apps/thumbnailers -pdf` | |
| `opencl` | `media-libs/mesa -opencl` | no Mesa OpenCL (ROCm is separate, Appendix C) |
| `steam` | 73 lines of `abi_x86_32` | Steam's 32-bit stack: Mesa, LLVM, glibc, X11/xcb, audio libraries. Includes `sys-libs/gdbm` and `sys-libs/readline` (needed by 32-bit `pam` via `libcap`, or `@world` does not resolve) |

**Why:** setting these before installing anything avoids rebuilding half the system later. The Steam list in particular changes LLVM and Mesa.

Keep **no backups inside `/etc/portage`**: Portage reads every file in `package.use/` etc., including `foo.bak`.

### 1.5 Binhost client (Battleship)

Frankenstein compiles and serves signed binaries; the Battleship installs them. Server side: Appendix A.

**Do:**
1. Check the server: `curl -s -o /dev/null -w "HTTP %{http_code}\n" http://192.168.1.9:8080/Packages` → `HTTP 200`.
2. Remove Gentoo's official binhost (`/etc/portage/binrepos.conf/gentoobinhost.conf`) and add [`binrepos.conf/frankenstein.conf`](etc/battleship/portage/binrepos.conf/frankenstein.conf):
   ```ini
   [frankenstein]
   priority = 10
   sync-uri = http://192.168.1.9:8080
   ```
3. Trust the signing key. Run `getuto` if `/etc/portage/gnupg` does not exist yet, download `http://192.168.1.9:8080/binhost-signing.asc`, **check the fingerprint** `8838 6760 B669 D0AD BC01  D926 EB26 C91F 3ABB 14F8`, then:
   ```bash
   gpg --homedir /etc/portage/gnupg --import binhost-signing.asc
   gpg --homedir /etc/portage/gnupg --batch --yes --pinentry-mode loopback \
       --passphrase-file /etc/portage/gnupg/pass --quick-lsign-key 88386760B669D0ADBC01D926EB26C91F3ABB14F8
   ```
4. In `make.conf`:
   ```bash
   EMERGE_DEFAULT_OPTS="--jobs=16 --load-average=14 --getbinpkg=y --binpkg-respect-use=y --usepkg-exclude=\"sys-kernel/gentoo-kernel virtual/dist-kernel app-admin/ryzen_smu\""
   ```

**Why:**
- Signatures are verified by default. **Never set `verify-signature = false`**: anything on the LAN pretending to be `192.168.1.9` could then serve packages that get installed as root.
- `--binpkg-respect-use=y` only takes a binary if its USE flags match; otherwise it compiles.
- The kernel and out-of-tree modules are always built locally: they are built for Frankenstein's own kernel.
- Fetched binaries are cached in `/var/cache/binhost/frankenstein`.

**Verify:** `emerge -pv sys-block/parted` → the line starts with `[binary`. A downloaded package verifies as `Good signature from "Frankenstein binhost" [full]`.

---

## Part 2 – Toolchain and core tools

### 2.1 CPU flags

**Do:**
```bash
sudo emerge -1 app-portage/cpuid2cpuflags
echo "CPU_FLAGS_X86=\"$(cpuid2cpuflags | cut -d' ' -f2-)\"" | sudo tee -a /etc/portage/make.conf
```
Both machines: `aes avx avx2 bmi1 bmi2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3 vpclmulqdq`.

**Why:** packages use this to enable hand-written SIMD code. (`adx`, `rdseed` and `vaes` no longer exist as Portage flags; older guides listing them are stale.)

### 2.2 Mold linker

**Do:** `sudo emerge sys-devel/mold`, **then** change `make.conf`:
```bash
LDFLAGS="${COMMON_FLAGS} -Wl,-O1 -Wl,--as-needed -fuse-ld=mold"
RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=mold"
```
**Why:** linking large C++ and Rust packages takes seconds instead of minutes.

### 2.3 ccache

**Do:** `sudo emerge dev-util/ccache`, then in `make.conf`:
```bash
FEATURES="ccache parallel-fetch parallel-install"
CCACHE_DIR="/var/cache/ccache"
```
**Why:** rebuilds of the same package (revision bumps, USE changes) reuse earlier compile results.

### 2.4 Core tools

**Do:**
```bash
sudo emerge app-portage/eix app-portage/gentoolkit app-portage/portage-utils app-admin/sudo \
            app-shells/zsh app-shells/fzf
```
**Why:** `eix-sync` is used by the `up` alias; `gentoolkit` provides `equery`, `revdep-rebuild`, `eclean-*`, `glsa-check`; `portage-utils` provides `qlop`, `qfile`, `qcheck`. zsh and fzf are the shell (Part 5.6); fzf's history search needs `dev-lang/perl` (already installed).

### 2.5 Rebuild everything with the final flags

**Do:** `sudo emerge -uDN --with-bdeps=y @world`

**Verify:** `emerge -pvuDN --with-bdeps=y @world` → `Total: 0 packages`.

---

## Part 3 – Kernel and boot

### 3.1 Kernel config fragments

The distribution kernel (`sys-kernel/gentoo-kernel`) is built from source with Gentoo's default config plus the fragments in `/etc/kernel/config.d/`.

**Do:** `/etc/kernel/config.d/10-zen3-gaming.config` ([battleship](etc/battleship/kernel/config.d/10-zen3-gaming.config), [frankenstein](etc/frankenstein/kernel/config.d/10-zen3-gaming.config)):
```ini
CONFIG_X86_NATIVE_CPU=y
CONFIG_HZ_1000=y
CONFIG_HZ=1000
CONFIG_PREEMPT=y
CONFIG_RCU_EXPERT=y
CONFIG_RCU_BOOST=y
CONFIG_RCU_BOOST_DELAY=500
CONFIG_SCHED_SMT=y
CONFIG_SCHED_MC=y
CONFIG_SCHED_HRTICK=y
CONFIG_HIGH_RES_TIMERS=y
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y
CONFIG_DEFAULT_MMAP_MIN_ADDR=65536
CONFIG_LOCALVERSION="-5800x3dv9070xt"
```
and `20-desktop-essentials.config` (USB storage, exFAT/NTFS/ISO/UDF, the board sensor, USB audio and webcams, gamepads and `uinput` for Steam Input, TUN/WireGuard/bridge/overlay, Bluetooth modules): see [battleship](etc/battleship/kernel/config.d/20-desktop-essentials.config) and [frankenstein](etc/frankenstein/kernel/config.d/20-desktop-essentials.config).

| Setting | Battleship | Frankenstein |
|---|---|---|
| `CONFIG_LOCALVERSION` | `"-5800x3dv9070xt"` | `"-5700v6650"` |
| Board sensor | `CONFIG_SENSORS_NCT6683=m` | `CONFIG_SENSORS_NCT6775=m` |

**Why:**
- `X86_NATIVE_CPU`: builds the kernel with `-march=native`. **Do not use `CONFIG_MZEN3`, `MZEN4`, `MCORE2`, `GENERIC_CPU`:** mainline removed these per-CPU options (6.18 has none of them). Kconfig silently ignores them and you get a generic x86-64 kernel.
- 1000 Hz tick and full preemption: lower scheduling latency and steadier frame pacing.
- `RCU_BOOST` is only offered when `RCU_EXPERT=y`; without it, both boost lines are silently dropped. `RCU_EXPERT` only unlocks the options, all other RCU defaults stay.
- THP `madvise`: huge pages only where programs ask for them.
- Sensors: the MSI B550's NCT6687D is handled by the in-kernel **`nct6683`** driver. `CONFIG_SENSORS_NCT6687` does not exist in mainline (it is a separate out-of-tree driver).

Keep nothing else in `/etc/kernel/config.d/`: every file there is merged into the kernel config, backups included.

### 3.2 Kernel, firmware, bootloader

**Do:**
```bash
sudo emerge sys-kernel/linux-firmware sys-kernel/installkernel sys-boot/grub
sudo emerge --select sys-kernel/gentoo-kernel
sudo grub-install --target=x86_64-efi --efi-directory=/boot
```
`/etc/default/grub` ([battleship](etc/battleship/default/grub)):
```bash
GRUB_DISTRIBUTOR="Gentoo"
GRUB_TIMEOUT=3
GRUB_CMDLINE_LINUX_DEFAULT="amd_pstate=active quiet amdgpu.dcdebugmask=0x10 amdgpu.gpu_recovery=1 amdgpu.ppfeaturemask=0xffffffff"
```
then `sudo grub-mkconfig -o /boot/grub/grub.cfg`.

**Why:**
- `--select` puts the kernel in `@world`, so `up` builds every new kernel and `depclean` never removes the kernel, dracut or installkernel.
- installkernel (with `dracut grub`) builds the initramfs and runs `grub-mkconfig` on every kernel install. Dracut builds a smaller host-only initramfs when called by installkernel; if you need a new initramfs, use `sudo emerge --config '=sys-kernel/gentoo-kernel-<ver>'`, not `dracut` directly (a direct call builds a generic, much bigger image).
- `amd_pstate=active`: the CPU's own frequency control (EPP mode).
- `amdgpu.dcdebugmask=0x10`: fixes desktop freezes on high-refresh monitors (144/240/360 Hz: frame deadlines of 6.94/4.16/2.77 ms). The display engine's power saving drops clocks at idle and cannot ramp up in time for the next frame; symptoms were `flip_done timed out` / `Pageflip timed out` in `dmesg`.
- `amdgpu.gpu_recovery=1`: reset the GPU instead of hanging when it locks up.
- `amdgpu.ppfeaturemask=0xffffffff`: makes OverDrive (the undervolt, Part 4.12) writable.
- The amdgpu options live **only** on the kernel command line. Do not also put them in `/etc/modprobe.d/`.

The EFI loader ends up in `/boot/EFI/Gentoo/grubx64.efi`. After every GRUB package upgrade, run `grub-install` again (plus `grub-mkconfig`): the package upgrade alone does not replace the loader in `/boot`.

**Verify:** `strings /boot/EFI/Gentoo/grubx64.efi | grep -m1 -oE '2\.1[0-9]'` matches the installed GRUB version; `efibootmgr` shows `\EFI\Gentoo\grubx64.efi`.

### 3.3 Modules to load at boot

**Do:** `/etc/modules-load.d/` ([battleship](etc/battleship/modules-load.d/)):

| File | Content | Machine |
|---|---|---|
| `sensors.conf` | `nct6683` | Battleship (Frankenstein: `nct6775`) |
| `ntsync.conf` | `ntsync` | both |
| `ryzen_smu.conf` | `ryzen_smu` | Battleship (needs `app-admin/ryzen_smu`, Part 5.4) |

**Why:** `nct6683` does not load by itself; without it there are no fan, voltage or board temperature readings. `ntsync` gives recent Wine/Proton fast Windows synchronisation primitives through `/dev/ntsync`; the kernel has it as a module but nothing loads it.

### 3.4 [reboot] Verify the kernel

```bash
uname -r                                   # 7.2.8-5800x3dv9070xt
cat /proc/cmdline                          # contains the amdgpu options
K=$(zcat /proc/config.gz)
for l in $(grep -hE '^CONFIG_' /etc/kernel/config.d/*.config); do
  echo "$K" | grep -qxF "$l" || echo "MISSING: $l"
done                                       # prints nothing
lsmod | grep -E 'nct6683|ntsync|ryzen_smu' # three lines
ls -l /dev/ntsync                          # crw-rw-rw-
```
Run the fragment check after **every** new kernel: Kconfig drops options without a word when they are renamed, removed or missing a dependency. That is how the dead `MZEN3`, the ineffective `RCU_BOOST` and the non-existent `NCT6687` were found.

---

## Part 4 – System tuning and services

### 4.1 Performance sysctls

**Do:** [`/etc/sysctl.d/99-performance.conf`](etc/battleship/sysctl.d/99-performance.conf), then `sudo sysctl --system`:
```ini
# Memory and swap (tuned for zram)
vm.swappiness = 10
vm.page-cluster = 0
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Stutter and gaming limits
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.max_map_count = 2147483642

# File handles and inotify
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024

# Network: BBR, fair queueing, larger buffers
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Gaming: don't stall split-lock accesses (SteamOS default)
kernel.split_lock_mitigate = 0
```
**Why:**
- `page-cluster = 0`: zram swaps single pages; read-ahead only wastes work.
- `dirty_*`: start writing back early, so large file copies don't freeze the desktop.
- `watermark_boost_factor = 0`: avoids kswapd wake-ups that cause random 50–100 ms stutters.
- `max_map_count`: some Proton games need far more memory mappings than the default.
- `split_lock_mitigate = 0`: by default the kernel deliberately slows down programs that do split-lock memory accesses; some Unity and older games do this constantly and slow down badly.

**Verify:** each key with `sysctl <key>`, e.g. `sysctl vm.swappiness kernel.split_lock_mitigate`.

### 4.2 IPv6 off

**Do:** [`/etc/sysctl.d/99-disable-ipv6.conf`](etc/battleship/sysctl.d/99-disable-ipv6.conf):
```ini
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```
and tell NetworkManager too:
```bash
sudo nmcli con mod "Wired connection 1" ipv6.method disabled
sudo nmcli con up "Wired connection 1"
```
**Why:** the ISP's IPv6 path black-holes large packets, which made long streaming connections (AI tools, gRPC/SSE) die mid-response. Without the NetworkManager setting, NM still asks for IPv6 and writes the ISP's IPv6 DNS servers into `/etc/resolv.conf`, which are unreachable with IPv6 off.

**Verify:** `grep nameserver /etc/resolv.conf` → only the router (`192.168.1.1`); `ip -6 addr` shows nothing on the LAN interface.

### 4.3 zram swap

**Do:** [`/etc/local.d/zram.start`](etc/battleship/local.d/zram.start) (executable):
```sh
#!/bin/sh
modprobe zram num_devices=1
echo lz4 > /sys/block/zram0/comp_algorithm
MEM_TOTAL_G=$(awk '/MemTotal/{print int($2/1024/1024)}' /proc/meminfo)
echo "${MEM_TOTAL_G}G" > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 32767 /dev/zram0
```
**Why:** compressed swap in RAM, sized to 100 % of RAM. With LZ4 (~2.5:1) a full 32 GB zram uses ~12–14 GB of real RAM, so huge builds (LLVM, qtwebengine, Chrome-class packages) never hit the OOM killer or the SSD. Frankenstein (16 GB) additionally has a 16 GB NVMe swap partition at priority 1 as a safety net.

**Verify:** `swapon --show` → `/dev/zram0`, size ≈ RAM, priority 32767.

### 4.4 `/tmp` in RAM

**Do:** add to `/etc/fstab` ([battleship](etc/battleship/fstab)); it takes effect at the next boot:
```
tmpfs   /tmp   tmpfs   size=8G,mode=1777,nosuid,nodev,noatime   0 0
```
**Why:** temporary files never touch the SSD. `8G` is a cap, not a reservation. Do not mount it over a running session: live sockets in `/tmp` (Xwayland, SDDM) would be hidden and apps break until logout.

**Verify (after reboot):** `findmnt /tmp` → `tmpfs`, `8G`.

### 4.5 OpenRC

**Do:** in `/etc/rc.conf`:
```ini
rc_parallel="YES"
rc_shell=/sbin/sulogin
unicode="YES"
rc_tty_number=12
```
Runlevels on the Battleship:

| Runlevel | Services |
|---|---|
| sysinit | cgroups devfs dmesg kmod-static-nodes sysfs systemd-tmpfiles-setup-dev udev udev-trigger |
| boot | binfmt bootmisc **consolefont** elogind fsck hostname hwclock **keymaps** localmount loopback modules mtab procfs root save-keymaps save-termencoding seedrng swap sysctl systemd-tmpfiles-setup termencoding |
| default | **chronyd cronie** dbus display-manager local **metalog** NetworkManager numlock power-profiles-daemon **ufw** |

`netmount` is removed (`sudo rc-update del netmount default`): there are no network filesystems.

**Why:** parallel start shortens boot. `local` runs the `/etc/local.d/*.start` scripts (zram, GPU undervolt).

### 4.6 Open-file limit

**Do:** [`/etc/security/limits.d/30-nofile.conf`](etc/battleship/security/limits.d/30-nofile.conf):
```
*    soft    nofile    524288
*    hard    nofile    524288
```
**Why:** Steam and Proton (esync) need many file descriptors; the default 4096 is too low. SDDM logins go through `pam_limits` (sddm → system-login → system-auth).

**Verify (after re-login):** `ulimit -n` → `524288`.

### 4.7 Cron, TRIM, locate database

**Do:**
```bash
sudo emerge sys-process/cronie sys-apps/plocate
sudo rc-update add cronie default && sudo rc-service cronie start
sudo updatedb
```
and [`/etc/cron.weekly/fstrim`](etc/battleship/cron.weekly/fstrim) (executable):
```sh
#!/bin/sh
# Weekly TRIM for all mounted filesystems that support it (NVMe SSD)
exec /sbin/fstrim -a
```
**Why:** Gentoo installs **no cron daemon by default**, so `/etc/cron.daily` (plocate database, man-db, tmpfiles cleanup) never runs. cronie's anacron also catches up on jobs missed while the PC was off. Without TRIM (no `discard` option, no job) SSD write performance slowly degrades.

**Verify:** `rc-service cronie status`; `sudo fstrim -av` reports trimmed space on `/` and `/boot`.

### 4.8 Time sync

**Do:**
```bash
sudo emerge net-misc/chrony
sudo rc-update add chronyd default && sudo rc-service chronyd start
```
In [`/etc/conf.d/chronyd`](etc/battleship/conf.d/chronyd): `ARGS="-4 -u ntp -F 2"` (IPv4 only, matching 4.2). In [`/etc/conf.d/hwclock`](etc/battleship/conf.d/hwclock): `clock_systohc="NO"`.

**Why:** without a time daemon the clock drifts (it was 0.42 s off), which breaks TLS, 2FA codes and log times. chrony's `rtcsync` (on by default) keeps the hardware clock in sync, so the `hwclock` service no longer needs to write it at shutdown; it still reads it at boot.

**Verify:** `chronyc tracking` → `Leap status : Normal`, system time off by milliseconds.

### 4.9 Persistent logs

**Do:** `sudo rc-update add metalog default && sudo rc-service metalog start` (install `app-admin/metalog` if missing).

**Why:** without a syslog daemon, nothing from a previous boot survives, so a freeze leaves no evidence. metalog's defaults write each line immediately (buffering only with `-a`); files rotate at 1 MB, 5 per folder, 30 days.

**Verify:** `sudo tail /var/log/everything/current` and `/var/log/kernel/current`.

### 4.10 Firewall

**Do:**
```bash
sudo emerge net-firewall/ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo rc-update add ufw default && sudo rc-service ufw start
```
**Why:** nothing listens on the network today, but a default-deny rule is the safety net for anything that opens a port later. The Battleship only fetches *from* the binhost, so it needs no open ports. To open one later: e.g. `sudo ufw allow 27036/tcp`. The kernel log will show `[UFW BLOCK]` lines for the router's multicast (IGMP) queries; that is normal.

**Verify:** `sudo ufw status verbose` → `deny (incoming), allow (outgoing)`; the binhost and internet still answer.

### 4.11 power-profiles-daemon

**Do:** `sudo emerge sys-power/power-profiles-daemon`, add it to the default runlevel, and create [`/etc/conf.d/power-profiles-daemon`](etc/battleship/conf.d/power-profiles-daemon):
```sh
supervisor="supervise-daemon"
respawn_delay=2
respawn_max=0
rc_need="dbus"
```
Profile: `powerprofilesctl set performance`.

**Why:** KDE's power widget talks to it. The supervisor restarts it if it dies. Keep these settings in `conf.d`, **not** in an edited `/etc/init.d/power-profiles-daemon`: package updates replace or prompt about init scripts and the edit gets lost.

**Verify:** `ps -eo args | grep '^supervise-daemon power-profiles'`; kill the daemon and it is back within seconds; `powerprofilesctl get` → `performance`.

### 4.12 GPU undervolt

**Needs** `amdgpu.ppfeaturemask=0xffffffff` (Part 3.2). Applied at boot by `/etc/local.d/amdgpu-undervolt.start`, logged to `/var/log/amdgpu-undervolt.log`.

Never reuse numbers from another card. Research the exact card, then measure.

#### Battleship: RX 9070 XT (RDNA 4)

RDNA 4 uses **offsets**, not absolute clocks. `pp_od_clk_voltage` offers:
```
OD_SCLK_OFFSET:    offset from the card's internal maximum GFX clock   -500 .. +1000 MHz
OD_VDDGFX_OFFSET:  voltage offset                                       -200 .. 0 mV
OD_MCLK:           memory clock range                                    97 .. 1500 MHz
```
Commands: `vo <mV>`, `s <MHz>` (one number, no index; the RDNA 2 form `s 1 <MHz>` fails with `Invalid argument`), `c` to commit.

The internal maximum (~3430 MHz on this card) is far above the advertised 3060 MHz boost, so `offset = target − 3060` does not work. Measured with a full-screen WebGL2 shader loop in a throwaway Chrome profile, sampling `hwmon/freq1_input`, `power1_average` and `temp1_input` every 0.2 s for 20 s:

| Setting | Peak clock | Avg clock | Power avg / peak | Edge temp |
|---|---|---|---|---|
| -60 mV, no offset | 3307 MHz | 3213 MHz | ~347 W (power limit) | 48 °C |
| -100 mV, -407 MHz | 3023 MHz | 2970 MHz | 207 / 244 W | 49 °C |
| **-100 mV, -500 MHz (daily)** | **2932 MHz** | **2882 MHz** | **236 / 276 W** | 52 °C |

-500 MHz is the driver's lower limit, so ~2930 MHz is the lowest reachable cap: about 10 % less clock for ~110 W less power.

[`/etc/local.d/amdgpu-undervolt.start`](etc/battleship/local.d/amdgpu-undervolt.start):
```bash
#!/bin/bash
# Sapphire Nitro+ RX 9070 XT (Navi 48 / RDNA 4): undervolt + clock cap.
# Wait up to 20 seconds for the GPU driver to initialize.
for i in {1..20}; do
    for card in /sys/class/drm/card*/device/pp_od_clk_voltage; do
        if [ -w "$card" ]; then
            echo "vo -100" > "$card"
            echo "s -500" > "$card"
            echo "c" > "$card"
            echo "[$(date)] Applied -100mV voltage offset and -500MHz clock offset (~2930MHz cap) to $card" >> /var/log/amdgpu-undervolt.log
            exit 0
        fi
    done
    sleep 1
done
echo "[$(date)] Timed out waiting for amdgpu pp_od_clk_voltage node" >> /var/log/amdgpu-undervolt.log
exit 1
```
If a game crashes or `dmesg` shows `ring … timeout` / `GPU reset`, go back to `vo -80` first and keep `s -500`.

No LACT: the only ebuild is in GURU (never used on this fleet), and an unpackaged copy once dropped into `/usr/bin` never ran and respawned every 2 s. The script above covers everything needed.

#### Frankenstein: RX 6650 XT (RDNA 2)

Absolute clock plus voltage offset: `-85 mV`, max `2550 MHz`, ~10 °C cooler hotspot without power throttling. Same script with:
```bash
echo "vo -85" > "$card"
echo "s 1 2550" > "$card"
echo "c" > "$card"
```

**Verify:** `cat /sys/class/drm/card*/device/pp_od_clk_voltage` and the log.

### 4.13 CPU: PBO, Curve Optimizer, CPPC (Battleship)

The 5800X3D's multiplier is locked; the real tuning is **Curve Optimizer (CO)**, a per-core voltage/frequency curve shift set in the BIOS (*PBO → Curve Optimizer*, AGESA 1.2.0.8 or later). **PBO** sets the power and current limits.

Readable from Linux with `app-admin/ryzen_smu` + `app-admin/ryzen_monitor` (`sudo ryzen_monitor`; `sudo ryzen_monitor -m` prints DRAM timings). CO values **cannot** be read reliably: there is no documented read path, and neighbouring SMU commands *write* CO/PBO. Never send raw SMU commands on a guess; check CO in the BIOS.

| PBO limit | Value |
|---|---|
| PPT | 142 W |
| TDC | 95 A |
| EDC | 130 A |
| THM | 90 °C |

Curve Optimizer (set in the BIOS), matched to the CPPC ranking (`/sys/devices/system/cpu/cpu*/acpi_cppc/highest_perf`):

| Core | CPPC | Rank | CO |
|---|---|---|---|
| 0 | 196 | 1 | -20 |
| 1 | 196 | 1 | -20 |
| 2 | 191 | 3 | -20 |
| 5 | 186 | 4 | -25 |
| 4 | 181 | 5 | -25 |
| 3 | 176 | 6 | -25 |
| 6 | 171 | 7 | -30 |
| 7 | 166 | 8 | -30 |

The best cores get the mildest CO: they boost highest and become unstable first. CO instability shows at **light single-core loads** (idle, browsing), not in all-core compiles; if random reboots happen at idle, back off cores 6 and 7 to -25 first. Under a 16-thread compile: ~4440 MHz all-core, ~96 W, 75–82 °C (normal for a 5800X3D; the V-Cache die traps heat).

`amd_pstate` active (EPP), preferred-core ranking enabled, governor/EPP/power profile `performance`.

Memory: DDR4-3200 CL16-20-20-39 1T, FCLK = UCLK = MCLK = 1600 MHz (1:1), the kit's rated XMP profile.

### 4.14 Console: keyboard, font, NumLock

**Do:**
- [`/etc/conf.d/keymaps`](etc/battleship/conf.d/keymaps): `keymap="trq"` (Turkish Q), `windowkeys="YES"`.
- [`/etc/conf.d/consolefont`](etc/battleship/conf.d/consolefont): `consolefont="ter-v16n"` (needs `media-fonts/terminus-font`) and `rc_need="udev-settle"`; `sudo rc-update add consolefont boot`.
- NumLock: `/etc/sddm.conf.d/numlock.conf` with `[General]` `Numlock=on`; `/etc/xdg/kcminputrc` with `[Keyboard]` `NumLock=0` (0 = on); `sudo rc-update add numlock default` for the TTYs.

**Why:** these only affect the text consoles (and NumLock everywhere); KDE and SDDM have their own keyboard settings. `consolefont` is not in any runlevel by default, and at boot it fails if it runs while the console switches from the EFI framebuffer to amdgpu's (~4.6–5.4 s): `rc_need="udev-settle"` makes it wait until udev has loaded amdgpu. Terminus covers Turkish characters (ğ ş ı İ), the default font does not.

**Verify:** `rc-service consolefont status` → `started` after a reboot; on Ctrl+Alt+F3 the `'` key gives `ı`.

### 4.15 Text consoles vs SDDM (VT2)

**Do:** in `/etc/inittab` ([battleship](etc/battleship/inittab)), disable the getty on tty2:
```
#c2:2345:respawn:/sbin/agetty 38400 tty2 linux
```
then `sudo telinit q`.

**Why:** OpenRC starts SDDM before the gettys; SDDM takes the first free VT (2) for its X server and keeps it running during the Plasma session (VT7). The getty on tty2 then opens the same VT, and **Ctrl+Alt+F2 freezes the display** (the system keeps running). Gentoo's `/etc/init.d/display-manager` describes this race in its comments. Text consoles are now on F1 and F3–F6, Plasma on F7.

**Verify:** `ps -eo tty,args | grep agetty` shows no tty2; `ps -eo args | grep '^/usr/bin/X'` shows `vt2`.

---

## Part 5 – Desktop and software

Check first with `emerge -pv <packages>`: `[binary …]` comes from the binhost, `[ebuild …]` compiles. Add `--noreplace` when some are already installed.

### 5.1 Desktop base

`kde-plasma/plasma-meta` `x11-misc/sddm` `gui-libs/display-manager-init` `media-video/pipewire` `media-video/wireplumber` `net-misc/networkmanager` `kde-apps/konsole` `kde-apps/dolphin` `kde-plasma/spectacle` `gui-apps/wl-clipboard` `gui-apps/xwaylandvideobridge` `www-client/google-chrome`

`/etc/conf.d/display-manager`: `DISPLAYMANAGER="sddm"`, `CHECKVT=7`; `sudo rc-update add display-manager default`. SDDM's greeter runs on X11 (`DisplayServer=x11`), the Plasma session on Wayland.

### 5.2 PipeWire latency

**Do:** [`~/.config/pipewire/pipewire.conf.d/10-latency.conf`](home/.config/pipewire/pipewire.conf.d/10-latency.conf) and the same in [`/etc/pipewire/pipewire.conf.d/`](etc/battleship/pipewire/pipewire.conf.d/10-latency.conf):
```
context.properties = {
    default.clock.rate          = 48000
    default.clock.allowed-rates = [ 44100 48000 88200 96000 192000 ]
    default.clock.quantum       = 64
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 1024
}
```
Apply live: `pw-metadata -n settings 0 clock.quantum 64` (same for `min-quantum 32`, `max-quantum 1024`).

**Why:** 64 samples at 48 kHz ≈ 1.3 ms buffer (up to ~5 ms with the graph); apps that need more can still ask for up to 1024. The user is in the `pipewire` group, which gets realtime priority from `/etc/security/limits.d/*-pw-*.conf`.

**Verify:** `pw-metadata -n settings 0 | grep quantum`.

### 5.3 Apps

| Package | Why |
|---|---|
| `media-video/mpv` | video player |
| `kde-apps/ark` `app-arch/7zip` `app-arch/unrar` `app-arch/zip` | archives in Dolphin |
| `kde-apps/kate` | text editor |
| `kde-apps/okular` | PDF and documents |
| `kde-apps/gwenview` | images |
| `kde-apps/ffmpegthumbs` `media-video/ffmpegthumbnailer` | video thumbnails in Dolphin |
| `media-plugins/gst-plugins-meta` | GStreamer codecs |
| `sys-fs/dosfstools` `sys-fs/exfatprogs` `sys-fs/ntfs3g` | FAT, exFAT, NTFS drives |

### 5.4 Hardware and diagnostics

`sys-apps/pciutils` `sys-apps/usbutils` `sys-apps/lm-sensors` `sys-apps/smartmontools` `dev-util/vulkan-tools` `dev-util/clinfo` `media-video/libva-utils` `sys-process/nvtop` `sys-process/btop` `sys-apps/inxi` `sys-apps/dmidecode` `app-admin/ryzen_smu` `app-admin/ryzen_monitor` (Battleship)

- `vainfo`: on the RX 9070 XT, radeonsi decodes H.264, HEVC 10-bit and AV1 and encodes H.264/HEVC.
- `vulkaninfo --summary`: RADV for both 64- and 32-bit (both `radeon_icd` files in `/usr/share/vulkan/icd.d/`).
- `sudo smartctl -H -A /dev/nvme0`: NVMe health; `sensors`: fans, board and GPU temperatures.
- btop at 100 ms: `update_ms = 100` in `~/.config/btop/btop.conf`.

### 5.5 Gaming

`games-util/steam-launcher` from `steam-overlay`, with `package.use/steam` (Part 1.4). The ~70 packages of the 32-bit stack compile locally unless Frankenstein carries the same `package.use/steam`.

Plain Steam, no layers: no gamemode (the CPU is already on `performance`), no MangoHud, no gamescope. What helps games here comes from the system itself: NTSYNC (3.3), `split_lock_mitigate = 0` and `max_map_count` (4.1), the open-file limit (4.6).

**VRR / adaptive sync stays off** in KDE (System Settings → Display): with Plasma 6 it now and then breaks games until any display setting is changed. The monitor supports 48–240 Hz (read from `/sys/kernel/debug/dri/*/DP-1/vrr_range`).

### 5.6 Shell (zsh)

**Needs** `app-shells/zsh` `app-shells/fzf` `dev-lang/perl`, and the extras `app-shells/zsh-completions` `app-shells/gentoo-zsh-completions` `app-shells/zsh-syntax-highlighting` `app-shells/zoxide`.

Gentoo ships **no system-wide zshrc**. Without `~/.zshrc`, zsh shows a bare `hostname%` prompt, keeps no history file and has no completion menu; `chsh -s /bin/zsh` alone is not enough.

**Do:** copy [`home/.zshrc`](home/.zshrc) to `~/.zshrc` and [`home/.local/bin/fzf-history-delete`](home/.local/bin/fzf-history-delete) to `~/.local/bin/` (executable). The `.zshrc` sets:
- prompt `user@host ~/dir (git-branch) [exit code] %` (`%` for a user, `#` for root: zsh's version of bash's `$`)
- shared history in `~/.zsh_history` (100k entries, no duplicates, lines starting with a space are not saved)
- completion menu, `~/.local/bin` in `PATH`, Home/End/Delete/Ctrl-arrow keys as Konsole sends them, Up/Down history search by prefix
- fzf `Ctrl-R` history search with `Ctrl-X` to delete entries
- `zoxide` (`z <part of a dir>`), the `up` alias, and syntax highlighting as the **last** line

**Ctrl-X delete, how it works:** fzf's `{+f}` passes the path of a temp file with the selected lines (`NUM<TAB>command`, continuation lines start with a TAB). `fzf-history-delete` is a `zsh -fi` script: zsh itself reads `~/.zsh_history`, drops the entries whose text matches exactly and writes the file back, which handles multi-line commands, non-ASCII text and special characters. It needs `-i` (a non-interactive zsh writes no history) and adds a dummy entry because `$history` lags one entry behind. `exclude-multi` removes the entries from the open list; after closing, the shell reloads its in-memory history.

**Verify:** a new Konsole tab shows the prompt; `~/.zsh_history` grows; Ctrl-R, select, Ctrl-X removes the entry from the file.

### 5.7 Fonts

Every real font package in `media-fonts/*` (~175 packages, ~1.2 GB, half of it CJK: `noto-cjk` alone is 276 MB), so text in any script renders. Left out: tools (`bdf2sfd`, `pcf2bdf`, `font-util`, `encodings`, `font-alias`), `fonts-meta`, the test font `ahem`, and legacy X11 bitmap fonts, which KDE on Wayland does not use.

```bash
cd /var/db/repos/gentoo/media-fonts && ls | grep -vx metadata.xml | grep -vE '^(bdf2sfd|pcf2bdf|font-util|encodings|font-alias|fonts-meta|ahem|font-.*(75dpi|100dpi|-misc|cyrillic)|artwiz-.*|dina|ohsnap|proggy-fonts|spleen|termsyn|glass-tty-vt220|efont-unicode|shinonome|wqy-bitmapfont|wqy-unibit|x11fonts-jmk|lfpfonts-.*|jisx0213-fonts|intlfonts|sgi-fonts|cronyx-fonts|font-arabic-misc|unifont|mikachan-font-(ttc|ttf))$' | sed 's#^#media-fonts/#' > /tmp/fonts.txt
sudo emerge -av --noreplace --keep-going --jobs=1 $(cat /tmp/fonts.txt) && sudo fc-cache -f
```
Use `--jobs=1`: with parallel jobs, several packages run `fc-cache` at once, one fails (`failed to write cache`), and emerge stops. Fonts are not on the binhost; only `media-gfx/fontforge` really compiles.

**Verify:** `fc-match sans-serif` → Liberation Sans, `fc-match monospace` → Liberation Mono, `fc-match emoji` → Noto Color Emoji.

### 5.8 Tools

`app-admin/eclean-kernel` (Part 7.4), `sys-apps/ripgrep` `sys-apps/fd` `sys-apps/bat` `sys-apps/eza` `app-misc/fastfetch` `sys-fs/duf` `net-misc/yt-dlp`.

### 5.9 One-shot install (after Parts 1–4)

```bash
sudo emerge -av --noreplace \
  media-video/mpv kde-apps/ark app-arch/7zip app-arch/unrar app-arch/zip kde-apps/kate kde-apps/okular \
  kde-apps/gwenview kde-apps/ffmpegthumbs media-video/ffmpegthumbnailer media-plugins/gst-plugins-meta \
  sys-fs/dosfstools sys-fs/exfatprogs sys-fs/ntfs3g \
  sys-apps/pciutils sys-apps/usbutils sys-apps/lm-sensors sys-apps/smartmontools dev-util/vulkan-tools \
  dev-util/clinfo media-video/libva-utils sys-process/nvtop sys-process/btop sys-apps/inxi sys-apps/dmidecode \
  app-shells/zsh-completions app-shells/gentoo-zsh-completions app-shells/zsh-syntax-highlighting app-shells/zoxide \
  app-admin/eclean-kernel sys-apps/ripgrep sys-apps/fd sys-apps/bat sys-apps/eza \
  app-misc/fastfetch sys-fs/duf net-misc/yt-dlp
```
Then Steam (5.5) and the fonts (5.7).

---

## Part 6 – Final verification

After a reboot, every line should give the expected result.

| Check | Command | Expected |
|---|---|---|
| Kernel | `uname -r` | `7.2.8-5800x3dv9070xt` (current version + suffix) |
| Fragments applied | loop from Part 3.4 | no `MISSING` lines |
| Kernel command line | `cat /proc/cmdline` | `amd_pstate=active … amdgpu.ppfeaturemask=0xffffffff` |
| GRUB loader | `strings /boot/EFI/Gentoo/grubx64.efi \| grep -m1 -oE '2\.1[0-9]'` | installed GRUB version |
| Modules | `lsmod \| grep -E 'nct6683\|ntsync\|ryzen_smu'` | three modules |
| Sensors | `sensors` | `nct6687` fans, `k10temp`, `amdgpu`, `nvme` |
| Undervolt | `cat /sys/class/drm/card*/device/pp_od_clk_voltage` | `-500Mhz`, `-100mV` |
| CPU | `cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference` | `performance` |
| Services | `rc-status -a \| grep -E 'stopped\|crashed'` | only `savecache`, `killprocs`, `mount-ro` (shutdown services) |
| Sysctls | `sysctl vm.swappiness kernel.split_lock_mitigate net.ipv4.tcp_congestion_control` | `10`, `0`, `bbr` |
| zram | `swapon --show` | `/dev/zram0`, ≈ RAM, prio 32767 |
| tmpfs | `findmnt /tmp /var/tmp/portage` | both `tmpfs` (8G, 28G) |
| File limit | `ulimit -n` | `524288` |
| IPv6 / DNS | `grep nameserver /etc/resolv.conf` | only `192.168.1.1` |
| Time | `chronyc tracking \| grep Leap` | `Normal` |
| Firewall | `sudo ufw status` | `active` |
| Logs | `sudo ls /var/log/everything/current` | exists |
| Console | Ctrl+Alt+F3, then Ctrl+Alt+F7 | sharp Terminus text login, back to Plasma |
| Vulkan | `vulkaninfo --summary \| grep driverName` | `radv` |
| Portage | `emerge -pvuDN --with-bdeps=y @world` | `Total: 0 packages` |
| Portage | `emerge -p --depclean` | `Number to remove: 0` |
| Security | `glsa-check -t all` | nothing |

---

## Part 7 – Maintenance

### 7.1 The `up` alias

In `~/.zshrc`:
```bash
alias up='sudo zsh -c "eix-sync && emerge -vuDN --with-bdeps=y --keep-going @world && emerge --depclean"'
```
- One `sudo zsh -c` for the whole chain, so a multi-hour build never stops at a password prompt before `depclean`.
- `eix-sync`: git sync (seconds) plus the eix database.
- `-uDN --with-bdeps=y`: update, whole dependency tree, rebuild on USE changes, keep build tools current.
- `--keep-going`: one failed package does not stop the rest.
- `depclean`: removes orphans afterwards.

### 7.2 Update order with the binhost

Binaries are only used when the version matches, so both machines must be on the same tree:
1. Frankenstein: `up` (sync, update, packages land on the binhost).
2. Battleship: update **without syncing again**:
   ```bash
   sudo emerge -vuDN --with-bdeps=y --keep-going @world && sudo emerge --depclean
   ```
   `up` would run `eix-sync` and move the Battleship's tree past Frankenstein's; newer packages would then compile locally.

Check first with `emerge -pvuDN --with-bdeps=y @world` (`[binary]` vs `[ebuild]`). Typical big update (2026-09-28): 474 packages, 391 binaries, 83 local builds, ~3 h, nearly all of it LLVM 22 + 23 built twice (64- and 32-bit for Steam).

### 7.3 Config file updates (`etc-update`)

After an update Portage may say `X config files in '/etc' need updating`. **Never auto-replace.**

- **Reject** (option 2, keep your file) when the update would drop your tuning. Real case after the 7.2.8 update: the new `/etc/rc.conf` would have removed `rc_parallel`, `unicode`, `rc_tty_number` and `rc_shell`; the new `/etc/default/grub` would have removed the whole kernel command line.
- **Accept** (option 1) new files you never touched, or changes that only touch comments. Comment-only changes are auto-merged by etc-update itself ("Automerging trivial changes").
- Automatic modes: `-3` and `-5` **replace all your files with defaults, never use them**. `-7` discards all updates and keeps your files (asks `rm: remove '._cfg…'?` per file, answer `y`); `-9` does the same after one `YES`.

### 7.4 Kernel updates

`up` builds new kernels automatically (`gentoo-kernel` is in `@world`). Afterwards:
1. Reboot, then run the fragment check (Part 3.4).
2. Remove old kernels: `sudo eclean-kernel -n 2` keeps the newest two and removes the rest, including `/boot` and `/lib/modules` leftovers. (`emerge --depclean` alone leaves those files behind: they belong to no package.)
3. `sudo grub-mkconfig -o /boot/grub/grub.cfg` if the menu still lists removed kernels.

To keep a known-good kernel while testing a new one: `sudo emerge --noreplace sys-kernel/gentoo-kernel:<ver>`, later `sudo emerge --deselect sys-kernel/gentoo-kernel:<ver>`.

`emerge --config sys-kernel/gentoo-kernel` (rebuilding the initramfs) leaves `.old` copies of vmlinuz, initramfs, config and System.map in `/boot`; remove them once the new files have booted.

Keep `sys-kernel/linux-headers` at the newest version in the tree (it always trails the kernel, e.g. headers 7.1 with kernel 7.2.8).

### 7.5 Routine checks

| Task | Command |
|---|---|
| News | `eselect news read` |
| Security advisories | `glsa-check -t all` |
| Broken libraries | `sudo emerge -av @preserved-rebuild` |
| Orphans | `sudo emerge -av --depclean` |
| Old downloads | `sudo eclean-dist -d` |
| Old binaries | `sudo eclean-pkg -d` |
| Config updates | `sudo etc-update` |
| NVMe health | `sudo smartctl -H /dev/nvme0` |
| Full rebuild (rarely) | `sudo emerge -ave --keep-going @world` |

---

## Appendix A – Home binhost (Frankenstein)

Frankenstein compiles, the Battleship installs. It works because both have the same CPU target (`znver3`), `CPU_FLAGS_X86`, profile, global USE and `~amd64`. The 5800X3D's extra cache changes performance, not the instruction set.

### Server

- `FEATURES="… buildpkg"`: every compile also saves a package in `PKGDIR=/var/cache/binpkgs` (gpkg, lz4).
- Initial fill without recompiling: `quickpkg --include-unmodified-config=y "*/*"`, then `chmod -R a+rX /var/cache/binpkgs` (`quickpkg` creates root-only folders).
- Served by `www-servers/lighttpd` on port 8080, `/etc/lighttpd/lighttpd.conf`:
  ```
  var.logdir = "/var/log/lighttpd"
  server.modules = ( "mod_accesslog" )
  include "/etc/lighttpd/mime.conf"
  server.username      = "lighttpd"
  server.groupname     = "lighttpd"
  server.document-root = "/var/cache/binpkgs"
  server.port          = 8080
  server.use-ipv6      = "disable"
  server.pid-file      = "/run/lighttpd.pid"
  server.errorlog      = var.logdir + "/error.log"
  accesslog.filename   = var.logdir + "/access.log"
  ```
  No `server.bind` (the address comes from DHCP; a bind to a changed address stops lighttpd from starting). `rc-update add lighttpd default`.
- Firewall: `ufw allow from 192.168.1.0/24 to any port 8080 proto tcp comment 'binhost (lighttpd)'`. **Never forward port 8080 on the router.**
- Reserve `192.168.1.9` for Frankenstein in the router (DHCP reservation).

### Signing

| | |
|---|---|
| Key | `Frankenstein binhost <binhost@gentoo-ryzen.lan>`, ed25519, sign-only, no expiry |
| Fingerprint | `8838 6760 B669 D0AD BC01  D926 EB26 C91F 3ABB 14F8` |
| Public key | `http://192.168.1.9:8080/binhost-signing.asc` |
| Private key | `/root/.gnupg` on Frankenstein only (no passphrase, so unattended builds can sign) |

- `gpg --homedir /root/.gnupg --quick-generate-key "Frankenstein binhost <binhost@gentoo-ryzen.lan>" ed25519 sign never`
- `make.conf`: `FEATURES="… buildpkg binpkg-signing"`, `BINPKG_GPG_SIGNING_KEY="0x88386760B669D0ADBC01D926EB26C91F3ABB14F8"`, `BINPKG_GPG_SIGNING_GPG_HOME="/root/.gnupg"`.
- Sign existing packages one file per call: `find /var/cache/binpkgs -name '*.gpkg.tar' -print0 | xargs -0 -n 1 -P 12 gpkg-sign --skip-signed`, then `emaint binhost --fix`.
- Export only the public key: `gpg --homedir /root/.gnupg --armor --export 0x<fingerprint> > /var/cache/binpkgs/binhost-signing.asc`.
- Frankenstein must trust its own key too (same commands as Part 1.5, step 3), or `emaint binhost --fix` rejects every package and writes an **empty index**.

### Notes

- "Ignored due to changed dependencies": packages packed with `quickpkg` keep the dependency metadata of their build. When the tree changes dependencies without a version bump, Portage rejects them. Fix on Frankenstein: `emerge -uDN --changed-deps=y --with-bdeps=y @world`.
- `quickpkg --include-unmodified-config=y` leaves out config files Frankenstein changed and puts an **empty stub** in their place (`# empty file because --include-config=n when quickpkg was used`). If the Battleship's copy of that file is still the untouched default, installing the binary overwrites it with the stub. This happened to `/etc/conf.d/keymaps`. Check with `sudo grep -rlF 'empty file because --include-config=n' /etc`.
- To get the Battleship's 32-bit Steam stack as binaries too, Frankenstein would need a build chroot carrying `package.use/steam`.
- Binhost use: `sudo awk '{print $1}' /var/log/lighttpd/access.log | sort | uniq -c` (requests per client), `sudo grep -c 'gpkg.tar' /var/log/lighttpd/access.log` (packages downloaded).
- Frankenstein builds its kernel with a stripped `savedconfig` (~100 modules, [`etc/frankenstein/portage/savedconfig/`](etc/frankenstein/portage/savedconfig/)). It was made for Frankenstein's hardware; the Battleship runs the full module set.

---

## Appendix B – Pitfalls

**zsh**
- A word starting with `=` is replaced by a command path: `emerge --depclean =sys-kernel/gentoo-kernel-6.18.50` fails with `not found`. Quote it: `'=sys-kernel/gentoo-kernel-6.18.50'`. (Same for `echo ===`.)
- Globs are expanded by your shell before `sudo`: `sudo rm /boot/*old*` fails with `no matches found` because `/boot` is root-only. Use exact names or `sudo zsh -c '…'`.
- A leading `!` inverts the exit status; in `! a && b`, `b` never runs when `a` succeeds. (In Claude Code, `!` at the prompt runs a command; in a terminal it does not.)

**Portage and config**
- Backups inside `/etc/portage` or `/etc/kernel/config.d` are read as config. Keep them elsewhere.
- Kconfig silently drops removed or renamed options and options with unmet dependencies (Part 3.4).
- Edited init scripts in `/etc/init.d` get replaced or prompted on updates; put settings in `/etc/conf.d` (4.11).
- Font installs with parallel jobs race on `fc-cache` (5.7).
- `quickpkg` config stubs (Appendix A).

**Boot and desktop**
- SDDM and a getty sharing VT2 freeze the display on Ctrl+Alt+F2 (4.15).
- `consolefont` fails at boot without `rc_need="udev-settle"` (4.14).
- Mounting a tmpfs over `/tmp` in a running session hides live sockets (4.4).
- A GRUB package upgrade does not update the EFI loader; run `grub-install` (3.2).
- Harmless kernel messages: `amdgpu … Unsupported screen format RA24` at login (KWin tries a pixel format the display engine rejects, then falls back); `clocksource: Watchdog remote CPU … read timed out` (a skipped cross-check; the TSC stays active); `Setting dangerous option gpu_recovery - tainting kernel`.

**Hardware**
- RDNA 4 OverDrive takes offsets, not absolute clocks (4.12).
- Never send raw SMU commands to "read" Curve Optimizer values (4.13).

---

## Appendix C – AI / ROCm reference

On consumer Radeons, fast weight offloading between RAM and VRAM in large model runs can trigger SDMA page faults (`Page not present`). Set these **only in the AI runner script** (e.g. `run_gpu.sh`), never globally: disabling SDMA system-wide hurts games and the compositor.
```bash
export HSA_ENABLE_SDMA=0
# 10.3.0 for RDNA 2 (RX 6650 XT), 11.0.0 for RDNA 3, 12.0.0 for RDNA 4 (RX 9070 XT)
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export PYTORCH_HIP_ALLOC_CONF="garbage_collection_threshold:0.6,max_split_size_mb:64"
```

---

## Appendix D – Policies

- **Source first.** Everything is compiled from source. The only binaries allowed come from the home binhost, which compiles them from source with the fleet's shared configuration. Never Gentoo's official binhost.
- **No layers, no bloat.** Plain Steam; no gamemode, MangoHud or gamescope. Install a package only when it fills a real gap.
- **No GURU overlay.**
- **Kernel.** `sys-kernel/gentoo-kernel` built from source and kept in `@world`; the fragment check after every new kernel; `linux-headers` at the newest version in the tree.
- **This repository.** When a tuning, rule or fix changes on a machine, update this README and the files in `etc/<machine>/` to match the verified live state. Commit and push to GitHub only with the user's approval.

## License

This guide is licensed under [CC BY 4.0](LICENSE) © Ogün Aydın: free to use, share and adapt, with credit.
