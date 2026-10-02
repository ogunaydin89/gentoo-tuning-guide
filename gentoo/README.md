# Gentoo Tuning Guide: workstation PC

A step-by-step guide to the Gentoo setup on the workstation PC (Ryzen 7 5700X, Radeon RX 6650 XT): a low-latency kernel on Gentoo's default config, a RAM build directory, zram, a quiet undervolt and the maintenance routine that keeps it all working. Everything here is verified on the real machine; the reference files are in [`etc/`](etc/) and the shared shell files in [`../common/home/`](../common/home/).

The gaming PC runs Arch Linux and has its own guide in [`../arch/`](../arch/).

> **Status.** The guide describes the target state of this PC. These items are written up but **not yet applied to the live machine**: the kernel on Gentoo's default config without `savedconfig` (Part 3.1, with THP `madvise`), removing `netmount` and the retired binhost service (`lighttpd`) from the runlevels, and the `buildpkg`/signing lines in `make.conf` (already removed from the reference file, still present live). Everything else matches the live system.

## Contents

- [Part 0 – Before you start](#part-0--before-you-start)
- [Part 1 – Portage foundation](#part-1--portage-foundation)
- [Part 2 – Toolchain and core tools](#part-2--toolchain-and-core-tools)
- [Part 3 – Kernel and boot](#part-3--kernel-and-boot)
- [Part 4 – System tuning and services](#part-4--system-tuning-and-services)
- [Part 5 – Desktop and software](#part-5--desktop-and-software)
- [Part 6 – Final verification](#part-6--final-verification)
- [Part 7 – Maintenance](#part-7--maintenance)
- [Appendix A – Pitfalls](#appendix-a--pitfalls)
- [Appendix B – AI / ROCm reference](#appendix-b--ai--rocm-reference)
- [Appendix C – Optional: CPU mining in a sandbox](#appendix-c--optional-cpu-mining-in-a-sandbox)
- [Appendix D – Policies](#appendix-d--policies)

---

## Part 0 – Before you start

### The machine

| | |
|---|---|
| CPU | Ryzen 7 5700X (8c/16t, Zen 3, 65 W TDP), target `znver3` |
| GPU | Radeon RX 6650 XT (RDNA 2, Navi 23), 8 GB |
| RAM | 16 GB DDR4-3600 |
| Board | A520M-HDV (Super I/O Nuvoton NCT6793D); no PBO or Curve Optimizer |
| Storage | NVMe: ext4 root (`discard`), 1 GiB FAT32 ESP at `/efi`, 16 GB swap partition |
| Software | Gentoo, profile `default/linux/amd64/23.0/desktop/plasma`, OpenRC, KDE Plasma 6 on Wayland, PipeWire, global `~amd64` |
| Kernel | `sys-kernel/gentoo-kernel` on Gentoo's default config plus the fragments in [`etc/kernel/config.d/`](etc/kernel/config.d/); release name suffix `-5700v6650` |
| Role | compile and batch machine (local AI, builds, optional CPU mining) |

### What this guide assumes

- A booting Gentoo stage3 install with the `desktop/plasma` OpenRC profile, a user in `wheel`, network working.
- UEFI boot with the EFI system partition mounted at **`/efi`**; kernels and initramfs live in `/boot` on the root filesystem.

### How steps are written

Each step has **Do** (what to change), **Why**, and **Verify** (a command and the expected result). Do the parts in order: later parts rely on earlier ones. Reboot points are marked **[reboot]**.

Copy files from `etc/` only after reading them: UUIDs in `etc/fstab` are placeholders, and the hardware values (sensor chip, undervolt, kernel suffix) belong to this machine only.

### Naming: kernel suffix

The kernel carries the CPU and GPU in its release name through `CONFIG_LOCALVERSION`, e.g. `uname -r` → `7.2.8-5700v6650`. It makes it obvious which config a kernel was built with.

### For AI assistants working on a different machine

- Detect the hardware first: `lscpu`, `cpuid2cpuflags`, `lspci -k | grep -EA3 "VGA|3D"`, `free -h`. Adapt `CPU_FLAGS_X86`, `VIDEO_CARDS`, the Super I/O sensor driver, `CONFIG_LOCALVERSION`, zram and tmpfs sizes.
- **Never carry a GPU undervolt from one card to another.** Voltage and frequency behaviour differ per GPU generation and per chip. Research the exact card, then measure (Part 4.10).
- No binary packages: everything is compiled from source (Appendix D).
- Ask the user before any system change, and before committing or pushing to this repository.

---

## Part 1 – Portage foundation

Small configuration only. The point of this part is that everything installed later is built once, with the right flags.

### 1.1 Git sync

**Do:** `/etc/portage/repos.conf/gentoo.conf` ([reference](etc/portage/repos.conf/gentoo.conf)):
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
sudo emerge -1 dev-vcs/git
sudo rm -rf /var/db/repos/gentoo && sudo emaint sync -r gentoo
```

**Why:** the `gentoo-mirror` repository is the "sync friendly" git mirror: it includes news, GLSAs and metadata. A git sync takes seconds.

**Verify:** `emaint sync -r gentoo` finishes without errors.

### 1.2 `make.conf` base

**Do:** start from [`etc/portage/make.conf`](etc/portage/make.conf), **but leave these out for now** (Part 2 adds them once the tools exist):

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

MAKEOPTS="-j16 -l16"
NINJAOPTS="-j16"
EMERGE_DEFAULT_OPTS="--jobs=16 --load-average=14 --getbinpkg=n --autounmask-write=y --autounmask-continue=y"

ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"

GRUB_PLATFORMS="efi-64"
VIDEO_CARDS="amdgpu radeonsi"

USE="wayland pipewire pipewire-alsa elogind dbus udev policykit lz4 zstd pulseaudio alsa vulkan opengl vdpau vaapi hwaccel screencast networkmanager sddm plasma dav1d svt-av1 jpegxl avif heif opus x264 x265 -systemd -telemetry -bluetooth -cups -modemmanager -handbook -doc -test"

FEATURES="parallel-fetch parallel-install"
LC_MESSAGES=C.utf8
PORTAGE_COMPRESS="lz4"
PORTAGE_COMPRESS_FLAGS="-T16"
```

**Why:**
- `-march=native` builds for the machine's own CPU (`znver3`).
- `-j16 -l16`: 16 threads, and the load limit lets all of them run. `--load-average=14` keeps `emerge --jobs` from starting more packages when the load is already high, so the desktop stays usable.
- **Global `~amd64`:** everything tracks testing together. Mixing stable and testing leads to version skew between runtimes and their virtuals, long backtracking, and a pile of keyword files. With global `~amd64`, `package.accept_keywords/` stays empty.
- `ACCEPT_LICENSE="*"` accepts all licenses, so no `package.license` file is needed (e.g. for Chrome).
- `--autounmask-write=y --autounmask-continue=y` lets Portage write the needed `package.use` entries itself and carry on; review what it wrote afterwards.
- The USE line drops Bluetooth, printing, modems, systemd and docs. CUPS still gets installed as a library because Chrome, GTK and Qt require it; no printing service runs.
- `wireplumber` and `zram` are **not** global USE flags: do not add them (they do nothing).

**Verify:** `emerge --info | grep -E '^(CFLAGS|USE|ACCEPT_KEYWORDS)='`.

### 1.3 Build directory in RAM

**Do:** add to `/etc/fstab` ([reference](etc/fstab)), then `sudo mount /var/tmp/portage`:
```
tmpfs   /var/tmp/portage   tmpfs   size=24G,uid=portage,gid=portage,mode=775,noatime   0 0
```
**Why:** compiling in RAM is faster and saves SSD writes. A tmpfs only uses RAM for what is in it; 24 GB is a cap, and zram (Part 4.3) plus the swap partition absorb the peaks on this 16 GB machine.

**Verify:** `findmnt /var/tmp/portage` → `tmpfs`.

### 1.4 `package.use` settings up front

**Do:** copy [`etc/portage/package.use/`](etc/portage/package.use/) to `/etc/portage/package.use/`:

| File | Content | Why |
|---|---|---|
| `00-installkernel.conf` | `sys-kernel/installkernel dracut grub` | builds the initramfs and updates GRUB on every kernel install |
| `00-kernel.conf` | `sys-kernel/gentoo-kernel -debug` | no debug symbols (much smaller, faster build) |
| `01-desktop.conf` | `pipewire sound-server`, `mesa vulkan vaapi vdpau`, `minizip-ng compat`, `libdrm video_cards_radeon`, `qtbase cups`, `wireplumber`, `plasma-meta`, `sddm` | desktop audio, Mesa video features; `libdrm[video_cards_radeon]` is required by radeonsi; `minizip-ng compat` is needed by `virtual/minizip` |
| `02-fixes.conf` | `pillow -truetype`, `zlib -minizip` | dependency-cycle and conflict fixes |
| `opencl` | `media-libs/mesa -opencl` | no Mesa OpenCL (ROCm is separate, Appendix B) |
| `electrum` | `pyqt6 multimedia quick` | USE flags one application needs |

**Why:** setting these before installing anything avoids rebuilding half the system later.

Keep **no backups inside `/etc/portage`**: Portage reads every file in `package.use/` etc., including `foo.bak`. Keep backups in `~/Desktop/Geçici` instead.

---

## Part 2 – Toolchain and core tools

### 2.1 CPU flags

**Do:**
```bash
sudo emerge -1 app-portage/cpuid2cpuflags
echo "CPU_FLAGS_X86=\"$(cpuid2cpuflags | cut -d' ' -f2-)\"" | sudo tee -a /etc/portage/make.conf
```
Result on this machine: `aes avx avx2 bmi1 bmi2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3 vpclmulqdq`.

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
**Why:** rebuilds of the same package (revision bumps, USE changes) reuse earlier compile results. A rebuild of the kernel that took 45 minutes cold took 3 minutes with a warm cache.

### 2.4 Core tools

**Do:**
```bash
sudo emerge app-portage/eix app-portage/gentoolkit app-portage/portage-utils app-admin/sudo \
            app-shells/zsh app-shells/fzf
```
**Why:** `eix-sync` is used by the `up` alias; `gentoolkit` provides `equery`, `revdep-rebuild`, `eclean-*`, `glsa-check`; `portage-utils` provides `qlop`, `qfile`, `qcheck`. zsh and fzf are the shell (Part 5.5); fzf's history search needs `dev-lang/perl`.

### 2.5 Rebuild everything with the final flags

**Do:** `sudo emerge -uDN --with-bdeps=y @world`

**Verify:** `emerge -pvuDN --with-bdeps=y @world` → `Total: 0 packages`.

---

## Part 3 – Kernel and boot

### 3.1 Kernel config fragments

The distribution kernel (`sys-kernel/gentoo-kernel`) is built from source on **Gentoo's default config**, plus the fragments in `/etc/kernel/config.d/`. The default config already enables the drivers a desktop needs (USB storage and serial adapters, filesystems, Bluetooth, gamepads); the fragments only add the tuning below. Do not use `savedconfig`: a saved, trimmed config silently drops drivers (USB serial chips, USB Ethernet and printers were missing from an earlier trimmed config).

**Do:** [`/etc/kernel/config.d/10-tuning.config`](etc/kernel/config.d/10-tuning.config):
```ini
CONFIG_X86_NATIVE_CPU=y
CONFIG_HZ_1000=y
CONFIG_HZ=1000
CONFIG_PREEMPT=y
CONFIG_RCU_EXPERT=y
CONFIG_RCU_BOOST=y
CONFIG_RCU_BOOST_DELAY=0
CONFIG_SCHED_SMT=y
CONFIG_SCHED_MC=y
CONFIG_SCHED_HRTICK=y
CONFIG_HIGH_RES_TIMERS=y
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y
CONFIG_DEFAULT_MMAP_MIN_ADDR=65536
CONFIG_LOCALVERSION="-5700v6650"
```
and [`/etc/kernel/config.d/20-hardware.config`](etc/kernel/config.d/20-hardware.config):
```ini
CONFIG_HWMON=y
CONFIG_SENSORS_NCT6775=m
```

**Why:**
- `X86_NATIVE_CPU`: builds the kernel with `-march=native`. **Do not use `CONFIG_MZEN3`, `MZEN4`, `MCORE2`, `GENERIC_CPU`:** mainline removed these per-CPU options (6.18 has none of them). Kconfig silently ignores them and you get a generic x86-64 kernel.
- 1000 Hz tick and full preemption: lower scheduling latency and steadier frame pacing and desktop response. This is a latency choice; a throughput-only kernel would use a lower tick and less preemption.
- `RCU_BOOST` is only offered when `RCU_EXPERT=y`; without it, the boost lines are silently dropped. `RCU_EXPERT` only unlocks the options, all other RCU defaults stay.
- THP `madvise`: huge pages only where programs ask for them. An earlier setup on `always` was dropped after a hugepage-related desktop failure on another machine.
- Sensors: the A520M-HDV's NCT6793D is handled by the in-kernel `nct6775` driver.

Keep nothing else in `/etc/kernel/config.d/`: every file there is merged into the kernel config, backups included.

### 3.2 Kernel, firmware, bootloader

**Do:**
```bash
sudo emerge sys-kernel/linux-firmware sys-kernel/installkernel sys-boot/grub
sudo emerge --select sys-kernel/gentoo-kernel
sudo grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Gentoo
```
`/etc/default/grub` ([reference](etc/default/grub)):
```bash
GRUB_DISTRIBUTOR="Gentoo"
GRUB_TIMEOUT=3
GRUB_DISABLE_OS_PROBER=false
GRUB_CMDLINE_LINUX_DEFAULT="amd_pstate=active quiet amdgpu.dcdebugmask=0x10 amdgpu.gpu_recovery=1 amdgpu.ppfeaturemask=0xffffffff"
```
then `sudo grub-mkconfig -o /boot/grub/grub.cfg`.

**Why:**
- `--select` puts the kernel in `@world`, so `up` builds every new kernel and `depclean` never removes the kernel, dracut or installkernel.
- installkernel (with `dracut grub`) builds the initramfs and runs `grub-mkconfig` on every kernel install. Dracut builds a smaller host-only initramfs when called by installkernel; if you need a new initramfs, use `sudo emerge --config '=sys-kernel/gentoo-kernel-<ver>'`, not `dracut` directly (a direct call builds a generic, much bigger image).
- `amd_pstate=active`: the CPU's own frequency control (EPP mode).
- `amdgpu.dcdebugmask=0x10`: fixes desktop freezes on high-refresh monitors. The display engine's power saving drops clocks at idle and cannot ramp up in time for the next frame; symptoms were `flip_done timed out` / `Pageflip timed out` in `dmesg`.
- `amdgpu.gpu_recovery=1`: reset the GPU instead of hanging when it locks up.
- `amdgpu.ppfeaturemask=0xffffffff`: makes OverDrive (the undervolt, Part 4.10) writable.
- The amdgpu options live **only** on the kernel command line. Do not also put them in `/etc/modprobe.d/`.

The EFI loader ends up in `/efi/EFI/Gentoo/grubx64.efi`. After every GRUB package upgrade, run `grub-install` again (plus `grub-mkconfig`): the package upgrade alone does not replace the loader on the ESP.

**Verify:** `sudo strings /efi/EFI/Gentoo/grubx64.efi | grep -m1 -oE '2\.1[0-9]'` matches the installed GRUB version; `efibootmgr` shows `\EFI\Gentoo\grubx64.efi`.

### 3.3 Modules to load at boot

**Do:** `/etc/modules-load.d/sensors.conf` ([reference](etc/modules-load.d/sensors.conf)) with the line `nct6775`.

**Why:** `nct6775` does not load by itself; without it there are no fan, voltage or board temperature readings.

### 3.4 [reboot] Verify the kernel

```bash
uname -r                                   # 7.2.8-5700v6650
cat /proc/cmdline                          # contains the amdgpu options
K=$(zcat /proc/config.gz)
for l in $(grep -hE '^CONFIG_' /etc/kernel/config.d/*.config); do
  echo "$K" | grep -qxF "$l" || echo "MISSING: $l"
done                                       # prints nothing
lsmod | grep nct6775                       # the sensor driver is loaded
cat /sys/kernel/mm/transparent_hugepage/enabled   # [madvise]
```
Run the fragment check after **every** new kernel: Kconfig drops options without a word when they are renamed, removed or missing a dependency. That is how the dead `MZEN3`, the ineffective `RCU_BOOST` and a non-existent sensor option were found.

---

## Part 4 – System tuning and services

### 4.1 Performance sysctls

**Do:** [`/etc/sysctl.d/99-performance.conf`](etc/sysctl.d/99-performance.conf), then `sudo sysctl --system`:
```ini
# Memory and swap (tuned for zram)
vm.swappiness = 10
vm.page-cluster = 0
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Stutter limits
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
```
**Why:**
- `page-cluster = 0`: zram swaps single pages; read-ahead only wastes work.
- `dirty_*`: start writing back early, so large file copies don't freeze the desktop.
- `watermark_boost_factor = 0`: avoids kswapd wake-ups that cause random 50–100 ms stutters.
- `max_map_count`: some programs (Proton games, large AI tools) need far more memory mappings than the default.

**Verify:** `sysctl vm.swappiness net.ipv4.tcp_congestion_control` → `10`, `bbr`.

### 4.2 IPv6 off

**Do:** [`/etc/sysctl.d/99-disable-ipv6.conf`](etc/sysctl.d/99-disable-ipv6.conf):
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

**Verify:** `grep nameserver /etc/resolv.conf` → only the router (`192.168.1.1`).

### 4.3 zram swap

**Do:** a custom OpenRC service, [`/etc/init.d/zram`](etc/init.d/zram) (executable), added to the boot runlevel with `sudo rc-update add zram boot`:
```sh
#!/sbin/openrc-run
description="Initialize 16GB LZ4 ZRAM compressed swap device"

depend() {
    before localmount
}

start() {
    ebegin "Starting 16GB LZ4 ZRAM compressed swap"
    modprobe zram num_devices=1 2>/dev/null || true
    echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
    echo 16G > /sys/block/zram0/disksize 2>/dev/null || true
    mkswap /dev/zram0 >/dev/null 2>&1
    swapon -p 32767 /dev/zram0
    eend $?
}

stop() {
    ebegin "Stopping ZRAM swap"
    swapoff /dev/zram0 2>/dev/null || true
    echo 1 > /sys/block/zram0/reset 2>/dev/null || true
    eend 0
}
```
**Why:** compressed swap in RAM, sized at 100 % of the 16 GB. With LZ4 (about 2.5:1) a full zram uses roughly 6 GB of real RAM, so big builds (LLVM, qtwebengine, Chrome-class packages) never hit the OOM killer or the SSD. The 16 GB NVMe swap partition (priority 1 in `fstab`) is the safety net behind it.

LZ4 is the CPU-cheap choice. zstd would fit more data in the same RAM at a higher CPU cost; `lz4hc` compresses slowly for little gain.

**Verify:** `swapon --show` → `/dev/zram0` 16G at priority 32767, then `/dev/nvme0n1p3` at priority 1.

### 4.4 OpenRC

**Do:** `/etc/rc.conf` ([reference](etc/rc.conf)):
```ini
rc_parallel="YES"
rc_shell=/sbin/sulogin
unicode="YES"
rc_tty_number=12
```
Runlevels ([`etc/runlevels.txt`](etc/runlevels.txt)):

| Runlevel | Services |
|---|---|
| boot | binfmt bootmisc elogind fsck hostname hwclock keymaps localmount loopback modules mtab procfs root save-keymaps save-termencoding seedrng swap sysctl systemd-tmpfiles-setup termencoding **zram** |
| default | **chronyd** dbus display-manager local **metalog** NetworkManager numlock power-profiles-daemon ufw |

`netmount` is removed (`sudo rc-update del netmount default`): there are no network filesystems.

**Why:** parallel start shortens boot. `local` runs the `/etc/local.d/*.start` scripts (the GPU undervolt).

### 4.5 TRIM

**Do:** the root filesystem is mounted with `discard` (see `etc/fstab`), so the SSD gets TRIM continuously and no TRIM job is needed. No cron daemon is installed.

**Why:** without TRIM (no `discard` option, no job) SSD write performance slowly degrades. If you ever drop `discard`, run `fstrim -a` weekly from a cron job.

**Verify:** `findmnt -no OPTIONS /` contains `discard`.

### 4.6 Time sync

**Do:**
```bash
sudo emerge net-misc/chrony
sudo rc-update add chronyd default && sudo rc-service chronyd start
```
In `/etc/conf.d/chronyd` ([reference](etc/conf.d/chronyd)): `ARGS="-4 -u ntp -F 2"` (IPv4 only, matching 4.2). Leave `/etc/conf.d/hwclock` at its default, which does not write the clock at shutdown.

**Why:** without a time daemon the clock drifts, which breaks TLS, 2FA codes and log times. chrony's `rtcsync` (on by default) keeps the hardware clock in sync, so the `hwclock` service no longer needs to write it at shutdown; it still reads it at boot.

**Verify:** `chronyc tracking` → `Leap status : Normal`, system time off by milliseconds.

### 4.7 Persistent logs

**Do:** `sudo rc-update add metalog default && sudo rc-service metalog start`.

**Why:** without a syslog daemon, nothing from a previous boot survives, so a freeze leaves no evidence. metalog writes each line immediately; files rotate at 1 MB, 5 per folder, 30 days.

**Verify:** `sudo tail /var/log/everything/current` and `/var/log/kernel/current`.

### 4.8 Firewall

**Do:**
```bash
sudo emerge net-firewall/ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo rc-update add ufw default && sudo rc-service ufw start
```
**Why:** nothing listens on the network today, but a default-deny rule is the safety net for anything that opens a port later. To open one later: e.g. `sudo ufw allow <port>/tcp`.

**Verify:** `sudo ufw status verbose` → `deny (incoming), allow (outgoing)`.

### 4.9 power-profiles-daemon

**Do:** `sudo emerge sys-power/power-profiles-daemon`, add it to the default runlevel, and set the profile with `powerprofilesctl set performance`.

**Why:** KDE's power widget talks to it. No `conf.d` tweaks are needed on this machine.

**Verify:** `powerprofilesctl get` → `performance`.

### 4.10 GPU undervolt

**Needs** `amdgpu.ppfeaturemask=0xffffffff` (Part 3.2). Applied at boot by `/etc/local.d/amdgpu-undervolt.start`, logged to `/var/log/amdgpu-undervolt.log`.

Never reuse numbers from another card. Research the exact card, then measure.

The RX 6650 XT (RDNA 2) takes an absolute clock plus a voltage offset: `-85 mV`, max `2550 MHz`, about 10 °C cooler hotspot without power throttling. [`etc/local.d/amdgpu-undervolt.start`](etc/local.d/amdgpu-undervolt.start):
```bash
#!/bin/bash
# Wait up to 20 seconds for the GPU driver to initialize.
for i in {1..20}; do
    for card in /sys/class/drm/card*/device/pp_od_clk_voltage; do
        if [ -w "$card" ]; then
            echo "vo -85" > "$card"
            echo "s 1 2550" > "$card"
            echo "c" > "$card"
            echo "[$(date)] Successfully applied -85mV undervolt to $card" >> /var/log/amdgpu-undervolt.log
            exit 0
        fi
    done
    sleep 1
done
echo "[$(date)] Timed out waiting for amdgpu pp_od_clk_voltage node" >> /var/log/amdgpu-undervolt.log
exit 1
```
Make it executable. If a program crashes or `dmesg` shows `ring … timeout` / `GPU reset`, reduce the offset first.

**Verify:** `cat /sys/class/drm/card*/device/pp_od_clk_voltage` shows `-85mV` and `2550Mhz`, and the log has a line.

### 4.11 CPU

The A520 board offers no PBO and no Curve Optimizer, so there is no BIOS tuning here. The settings that matter are on the software side: `amd_pstate=active` (Part 3.2) with the `performance` energy-performance preference.

**Verify:** `cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference` → `performance`.

### 4.12 Console: keyboard and NumLock

**Do:**
- [`/etc/conf.d/keymaps`](etc/conf.d/keymaps): `keymap="trq"` (Turkish Q), `windowkeys="YES"`.
- NumLock: [`/etc/sddm.conf.d/numlock.conf`](etc/sddm.conf.d/numlock.conf) with `[General]` `Numlock=on`; [`/etc/xdg/kcminputrc`](etc/xdg/kcminputrc) with `[Keyboard]` `NumLock=0` (0 = on); `sudo rc-update add numlock default` for the TTYs.
- SDDM ([`etc/sddm.conf.d/10-settings.conf`](etc/sddm.conf.d/10-settings.conf)): theme `breeze`, remember user and session, layout `tr`.

**Why:** the keymap affects the text consoles; KDE and SDDM have their own keyboard settings. The console font is the default one; Terminus (`media-fonts/terminus-font`, `consolefont="ter-v16n"`) covers Turkish characters (ğ ş ı İ) if you want them on the console. If you enable it, add `rc_need="udev-settle"` to `/etc/conf.d/consolefont`, otherwise the service can fail at boot while the console switches from the EFI framebuffer to amdgpu's.

**Verify:** a new TTY (Ctrl+Alt+F3) takes the Turkish layout, and NumLock is on after login.

---

## Part 5 – Desktop and software

Check first with `emerge -pv <packages>`: every `[ebuild …]` line compiles. Add `--noreplace` when some are already installed.

### 5.1 Desktop base

`kde-plasma/plasma-meta` `x11-misc/sddm` `gui-libs/display-manager-init` `media-video/pipewire` `media-video/wireplumber` `net-misc/networkmanager` `kde-apps/konsole` `kde-apps/dolphin` `kde-plasma/spectacle` `gui-apps/wl-clipboard` `www-client/google-chrome`

`/etc/conf.d/display-manager` ([reference](etc/conf.d/display-manager)): `DISPLAYMANAGER="sddm"`; `sudo rc-update add display-manager default`. SDDM's greeter runs on X11 (`DisplayServer=x11` in the package's default config), the Plasma session on Wayland.

### 5.2 PipeWire latency

**Do:** `~/.config/pipewire/pipewire.conf.d/10-latency.conf` and the same file in `/etc/pipewire/pipewire.conf.d/`:
```
context.properties = {
    default.clock.quantum = 256
    default.clock.min-quantum = 128
    default.clock.max-quantum = 1024
    default.clock.rate = 48000
}
```
**Why:** a 256-sample buffer at 48 kHz is about 5 ms. It is safe under heavy compile load; lower values (64/32) give less latency but can crackle when the CPU is saturated.

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

`sys-apps/pciutils` `sys-apps/usbutils` `sys-apps/lm-sensors` `sys-apps/smartmontools` `dev-util/vulkan-tools` `dev-util/clinfo` `media-video/libva-utils` `sys-process/nvtop` `sys-process/btop` `sys-apps/inxi` `sys-apps/dmidecode`

- `vulkaninfo --summary`: RADV for the RX 6650 XT.
- `sudo smartctl -H -A /dev/nvme0`: NVMe health; `sensors`: fans, board and GPU temperatures. Fans powered from the PSU by Molex show 0 RPM, because they have no tachometer wire to the board.

### 5.5 Shell (zsh)

**Needs** `app-shells/zsh` `app-shells/fzf` `dev-lang/perl`, and the extras `app-shells/zsh-completions` `app-shells/gentoo-zsh-completions` `app-shells/zsh-syntax-highlighting` `app-shells/zoxide`, plus `sys-apps/eza` and `sys-apps/bat` for colour.

Gentoo ships **no system-wide zshrc**. Without `~/.zshrc`, zsh shows a bare `hostname%` prompt, keeps no history file and has no completion menu; `chsh -s /bin/zsh` alone is not enough.

**Do:** copy [`../common/home/.zshrc`](../common/home/.zshrc) to `~/.zshrc` and [`../common/home/.local/bin/fzf-history-delete`](../common/home/.local/bin/fzf-history-delete) to `~/.local/bin/` (executable). The `.zshrc` sets:
- prompt `user@host ~/dir (git-branch) [exit code] %`
- shared history in `~/.zsh_history` (100k entries, no duplicates, lines starting with a space are not saved)
- completion menu, `~/.local/bin` in `PATH`, Home/End/Delete/Ctrl-arrow keys as Konsole sends them, Up/Down history search by prefix
- fzf `Ctrl-R` history search with `Ctrl-X` to delete entries
- `zoxide` (`z <part of a dir>`), the `up` alias, and syntax highlighting as the **last** line
- colour where it helps; everything switches colour off by itself in pipes and scripts, and `\ls`, `\cat` always run the plain originals

**Verify:** a new Konsole tab shows the prompt; `~/.zsh_history` grows; Ctrl-R, select, Ctrl-X removes the entry from the file; `echo ${#LS_COLORS}` is not 0.

### 5.6 Fonts

Every real font package in `media-fonts/*` (about 175 packages, about 1.2 GB, half of it CJK), so text in any script renders. Left out: tools (`bdf2sfd`, `pcf2bdf`, `font-util`, `encodings`, `font-alias`), `fonts-meta`, the test font `ahem`, and legacy X11 bitmap fonts.

```bash
cd /var/db/repos/gentoo/media-fonts && ls | grep -vx metadata.xml | grep -vE '^(bdf2sfd|pcf2bdf|font-util|encodings|font-alias|fonts-meta|ahem|font-.*(75dpi|100dpi|-misc|cyrillic)|artwiz-.*|dina|ohsnap|proggy-fonts|spleen|termsyn|glass-tty-vt220|efont-unicode|shinonome|wqy-bitmapfont|wqy-unibit|x11fonts-jmk|lfpfonts-.*|jisx0213-fonts|intlfonts|sgi-fonts|cronyx-fonts|font-arabic-misc|unifont|mikachan-font-(ttc|ttf))$' | sed 's#^#media-fonts/#' > /tmp/fonts.txt
sudo emerge -av --noreplace --keep-going --jobs=1 $(cat /tmp/fonts.txt) && sudo fc-cache -f
```
Use `--jobs=1`: with parallel jobs, several packages run `fc-cache` at once, one fails (`failed to write cache`), and emerge stops.

**Verify:** `fc-match sans-serif` → Liberation Sans, `fc-match monospace` → Liberation Mono, `fc-match emoji` → Noto Color Emoji.

**Optional, subpixel text:** Gentoo's fontconfig default is grayscale smoothing. RGB subpixel rendering (`~/.config/fontconfig/fonts.conf`: antialias on, `rgba` `rgb`, `lcdfilter` `lcddefault`, `hintstyle` `hintslight`) looks sharper, but it must match the panel's real subpixel layout; check the monitor first. It is not set on this machine.

### 5.7 Tools

`app-admin/eclean-kernel` (Part 7.4), `sys-apps/ripgrep` `sys-apps/fd` `sys-apps/bat` `sys-apps/eza` `app-misc/fastfetch` `sys-fs/duf` `net-misc/yt-dlp` `dev-util/github-cli`.

Install `dev-util/github-cli` **without** `--oneshot`: a one-shot install is not recorded in `@world`, and the `depclean` at the end of `up` removes it.

### 5.8 One-shot install (after Parts 1–4)

```bash
sudo emerge -av --noreplace \
  media-video/mpv kde-apps/ark app-arch/7zip app-arch/unrar app-arch/zip kde-apps/kate kde-apps/okular \
  kde-apps/gwenview kde-apps/ffmpegthumbs media-video/ffmpegthumbnailer media-plugins/gst-plugins-meta \
  sys-fs/dosfstools sys-fs/exfatprogs sys-fs/ntfs3g \
  sys-apps/pciutils sys-apps/usbutils sys-apps/lm-sensors sys-apps/smartmontools dev-util/vulkan-tools \
  dev-util/clinfo media-video/libva-utils sys-process/nvtop sys-process/btop sys-apps/inxi sys-apps/dmidecode \
  app-shells/zsh-completions app-shells/gentoo-zsh-completions app-shells/zsh-syntax-highlighting app-shells/zoxide \
  app-admin/eclean-kernel sys-apps/ripgrep sys-apps/fd sys-apps/bat sys-apps/eza \
  app-misc/fastfetch sys-fs/duf net-misc/yt-dlp dev-util/github-cli
```
Then the fonts (5.6).

---

## Part 6 – Final verification

After a reboot, every line should give the expected result.

| Check | Command | Expected |
|---|---|---|
| Kernel | `uname -r` | `7.2.8-5700v6650` (current version + suffix) |
| Fragments applied | loop from Part 3.4 | no `MISSING` lines |
| THP | `cat /sys/kernel/mm/transparent_hugepage/enabled` | `[madvise]` |
| Kernel command line | `cat /proc/cmdline` | `amd_pstate=active … amdgpu.ppfeaturemask=0xffffffff` |
| GRUB loader | `sudo strings /efi/EFI/Gentoo/grubx64.efi \| grep -m1 -oE '2\.1[0-9]'` | installed GRUB version |
| Sensors | `sensors` | `nct6793` fans, `k10temp`, `amdgpu`, `nvme` |
| Undervolt | `cat /sys/class/drm/card*/device/pp_od_clk_voltage` | `-85mV`, `2550Mhz` |
| CPU | `cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference` | `performance` |
| Services | `rc-status -a \| grep -E 'stopped\|crashed'` | only `savecache`, `killprocs`, `mount-ro` (shutdown services) |
| Sysctls | `sysctl vm.swappiness net.ipv4.tcp_congestion_control` | `10`, `bbr` |
| Swap | `swapon --show` | `/dev/zram0` 16G prio 32767, then the NVMe partition prio 1 |
| Build tmpfs | `findmnt /var/tmp/portage` | `tmpfs` (24G) |
| TRIM | `findmnt -no OPTIONS /` | contains `discard` |
| IPv6 / DNS | `grep nameserver /etc/resolv.conf` | only `192.168.1.1` |
| Time | `chronyc tracking \| grep Leap` | `Normal` |
| Firewall | `sudo ufw status` | `active` |
| Logs | `sudo ls /var/log/everything/current` | exists |
| USB tools | `lsusb` | lists devices |
| Vulkan | `vulkaninfo --summary \| grep driverName` | `radv` |
| Shell colour | `echo ${#LS_COLORS}` | not `0` |
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
- `depclean`: removes orphans afterwards. **Anything you want to keep must be in `@world`:** install tools without `--oneshot`.

Check first with `emerge -pvuDN --with-bdeps=y @world`.

### 7.2 Config file updates (`etc-update`)

After an update Portage may say `X config files in '/etc' need updating`. **Never auto-replace.**

- **Reject** (option 2, keep your file) when the update would drop your tuning. Real case after a 7.2.8 update: the new `/etc/rc.conf` would have removed `rc_parallel`, `unicode`, `rc_tty_number` and `rc_shell`; the new `/etc/default/grub` would have removed the whole kernel command line.
- **Accept** (option 1) new files you never touched, or changes that only touch comments. Comment-only changes are auto-merged by etc-update itself ("Automerging trivial changes").
- Automatic modes: `-3` and `-5` **replace all your files with defaults, never use them**. `-7` discards all updates and keeps your files (asks `rm: remove '._cfg…'?` per file, answer `y`); `-9` does the same after one `YES`.

### 7.3 Kernel updates

`up` builds new kernels automatically (`gentoo-kernel` is in `@world`). The full default config takes a while on a cold ccache and minutes on a warm one. Afterwards:
1. Reboot, then run the fragment check (Part 3.4).
2. Remove old kernels: `sudo eclean-kernel -n 2` keeps the newest two and removes the rest, including `/boot` and `/lib/modules` leftovers. (`emerge --depclean` alone leaves those files behind: they belong to no package.) Run `sudo eclean-kernel -n 2 -p` first (pretend) to see what goes.
3. `sudo grub-mkconfig -o /boot/grub/grub.cfg` if the menu still lists removed kernels.

To keep a known-good kernel while testing a new one, simply do not run `eclean-kernel` yet: the previous kernels stay in the GRUB menu.

`emerge --config sys-kernel/gentoo-kernel` (rebuilding the initramfs) leaves `.old` copies of vmlinuz, initramfs, config and System.map in `/boot`; remove them once the new files have booted.

Keep `sys-kernel/linux-headers` at the newest version in the tree. It trails the kernel (e.g. headers 7.1 with kernel 7.2.8); do not force it to match.

Long builds: a build started from an AI assistant's shell can be killed at the assistant's background time limit. Start a cold kernel build from your own terminal.

### 7.4 Routine checks

| Task | Command |
|---|---|
| News | `eselect news read` |
| Security advisories | `glsa-check -t all` |
| Broken libraries | `sudo emerge -av @preserved-rebuild` |
| Orphans | `sudo emerge -av --depclean` |
| Old downloads | `sudo eclean-dist -d` |
| Config updates | `sudo etc-update` |
| NVMe health | `sudo smartctl -H /dev/nvme0` |
| Full rebuild (rarely) | `sudo emerge -ave --keep-going @world` |

---

## Appendix A – Pitfalls

**zsh**
- A word starting with `=` is replaced by a command path: `emerge --depclean =sys-kernel/gentoo-kernel-6.18.50` fails with `not found`. Quote it: `'=sys-kernel/gentoo-kernel-6.18.50'`. (Same for `echo ===`.)
- Globs are expanded by your shell before `sudo`: `sudo rm /boot/*old*` fails with `no matches found` if the folder is not readable by you. Use exact names or `sudo zsh -c '…'`.
- A leading `!` inverts the exit status; in `! a && b`, `b` never runs when `a` succeeds. (In Claude Code, `!` at the prompt runs a command; in a terminal it does not.)

**Portage and config**
- Backups inside `/etc/portage` or `/etc/kernel/config.d` are read as config. Keep them elsewhere.
- Kconfig silently drops removed or renamed options and options with unmet dependencies (Part 3.4).
- A saved, trimmed kernel config (`savedconfig`) can silently lack drivers. Use Gentoo's default config plus fragments.
- Edited init scripts in `/etc/init.d` that belong to a package get replaced or prompted on updates; put settings in `/etc/conf.d`. Custom services (like the zram one) are unowned and safe.
- A tool installed with `--oneshot` is removed by the next `depclean` (Part 5.7).
- Font installs with parallel jobs race on `fc-cache` (5.6).

**Boot and desktop**
- A GRUB package upgrade does not update the EFI loader; run `grub-install` (3.2).
- `consolefont` with Terminus fails at boot without `rc_need="udev-settle"` (4.12).
- Mounting a tmpfs over `/tmp` in a running session hides live sockets (Xwayland, SDDM).
- If SDDM and a getty share a virtual console, Ctrl+Alt+F2 can freeze the display. Seen on the Arch gaming PC's earlier Gentoo install; not observed on this machine.
- `cpuidle.governor=teo` does nothing on Gentoo's kernel config: only the `menu` governor is built.
- Harmless kernel messages: `amdgpu … Unsupported screen format RA24` at login; `clocksource: Watchdog remote CPU … read timed out`; `Setting dangerous option gpu_recovery - tainting kernel`; `virt/tdx: TDX not supported by the host platform`; `amdgpu: Overdrive is enabled…` (expected with the undervolt).

**Hardware**
- Fans powered by Molex show 0 RPM in `sensors`: no tachometer signal.
- The A520 board has no PBO or Curve Optimizer; software cannot add them.

---

## Appendix B – AI / ROCm reference

On consumer Radeons, fast weight offloading between RAM and VRAM in large model runs can trigger SDMA page faults (`Page not present`). Set these **only in the AI runner script** (e.g. `run_gpu.sh`), never globally: disabling SDMA system-wide hurts the compositor.
```bash
export HSA_ENABLE_SDMA=0
# 10.3.0 for RDNA 2 (RX 6650 XT)
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export PYTORCH_HIP_ALLOC_CONF="garbage_collection_threshold:0.6,max_split_size_mb:64"
```

---

## Appendix C – Optional: CPU mining in a sandbox

The workstation can double as a space heater by mining Monero (RandomX). It is not part of the tuning, and it needs no system changes. The setup lives entirely in `~/.local/opt/xmrig/`:

- **Build from source, no root.** `git clone --depth 1 --branch v6.26.0 https://github.com/xmrig/xmrig.git`, then `cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DWITH_OPENCL=OFF -DWITH_CUDA=OFF -DCMAKE_C_FLAGS="-O2 -march=native -pipe" -DCMAKE_CXX_FLAGS="-O2 -march=native -pipe" -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=mold"` and `cmake --build build -j16` (about 30 s). Install the single `xmrig` binary and delete the source.
- **No hugepages, no MSR tweak.** `config.json` sets `huge-pages: false`, `1gb-pages: false`, `rdmsr: false`, `wrmsr: false`. The cost is small (about 3 % hashrate here: 7.7 kH/s against 7.9 kH/s) and it leaves the system untouched.
- **Donation:** xmrig enforces a minimum 1 % developer donation in builds from source; `donate-level: 0` is ignored.
- **Pool:** a small pool (about 2 % of the network at the time of writing) with a low minimum payout, set in `config.json`. The wallet address is a **public** address only; keep seed words offline and never in files or chats.
- **Sandbox:** `run-xmrig.sh` runs xmrig under `bwrap` with a read-only root, `/home` hidden, only the miner folder visible, network allowed, and `--die-with-parent` so it stops with its window.
- **Launcher:** a `.desktop` entry runs `launch-miner.sh`, which uses `flock` so only one instance runs and opens a Konsole window; closing the window stops the miner. Pin it to the Plasma task manager by writing the launcher list as a **list**, not a joined string, through Plasma's scripting interface; a joined string breaks every pinned icon.
- **Result:** about 7.5 kH/s at about 50 °C under full load on a 600 ₺ single-tower cooler.

---

## Appendix D – Policies

- **Source first.** Everything is compiled from source. No binary packages, from Gentoo's binhost or anywhere else.
- **No layers, no bloat.** Install a package only when it fills a real gap.
- **No GURU overlay.**
- **Kernel.** `sys-kernel/gentoo-kernel` on Gentoo's default config plus fragments, built from source and kept in `@world`; the fragment check after every new kernel; `linux-headers` at the newest version in the tree.
- **This repository.** When a tuning, rule or fix changes on a machine, update this README and the files in `etc/` to match the verified live state. Commit and push to GitHub only with the user's approval.

## License

This guide is licensed under [CC BY 4.0](../LICENSE) © Ogün Aydın: free to use, share and adapt, with credit.
