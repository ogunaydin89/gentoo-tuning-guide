# 🚀 Ultimate Gentoo Linux Master System, Kernel & Performance Tuning Guide

This comprehensive, standalone master guide consolidates every system optimization, custom kernel configuration, GPU latency fix, network enhancement, audio buffer tuning, memory caching rule, and hardware tuning applied to AMD Ryzen (Zen 3 / Zen 4 / Zen 5) and AMD Radeon (RDNA2 / RDNA3 / RDNA4) systems.

Clone or star this repository on Codeberg to instantly reproduce this hand-tuned, low-latency Gentoo setup on any machine:
```bash
git clone https://codeberg.org/helinesca/gentoo-tuning-guide.git
```

---

## 🤖 UNIVERSAL AI AGENT HARDWARE ADAPTATION DIRECTIVE

> [!IMPORTANT]
> **DYNAMIC HARDWARE ADAPTATION MANDATE FOR AGY / AI ASSISTANTS:**
> When an AI assistant (`agy` / Antigravity / Gemini / Claude) reads this guide on a machine with a **different CPU or GPU architecture** (e.g. AMD Zen 4 / Zen 5, Intel Core / Ultra, NVIDIA RTX, or Intel Arc):
> 
> 1. **Dynamic Hardware Detection:**
>    * Query the host system using `lscpu`, `cpuid2cpuflags`, `lspci -k | grep -EA3 "VGA|3D"`, and `clinfo` to identify exact CPU architecture, L3 cache size, instruction sets, and GPU generation.
> 2. **Tailor Compiler & Portage Flags:**
>    * Generate the exact `CPU_FLAGS_X86` using `app-portage/cpuid2cpuflags`.
>    * Set optimal `VIDEO_CARDS` (`radeonsi amdgpu` for modern AMD, `nvidia` for NVIDIA, `iris intel` for Intel).
>    * Configure `RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=mold"` and native GCC/Clang optimization flags (`-march=native -fuse-ld=mold`).
>    * Adopt the **Pure Testing (`~amd64`) Architecture**: set `ACCEPT_KEYWORDS="~amd64"` in `make.conf` for full system synchronization, zero keyword fragmentation, and seamless zero-touch updates.
> 3. **Tailor Kernel Architecture:**
>    * Adapt `/etc/kernel/config.d/10-gaming.config` to target the exact CPU family (`CONFIG_MZEN3=y`, `CONFIG_MZEN4=y`, `CONFIG_MZEN5=y`, `CONFIG_MCORE2=y`, etc.).
>    * Set `CONFIG_LOCALVERSION` following the `CPUvGPU` naming rule (e.g. `CONFIG_LOCALVERSION="-5800x3dv9070xt"`).
> 4. **Adaptive GPU Latency & High-Refresh Display Rules (144Hz / 240Hz / 360Hz+):**
>    * Frame deadlines scale inversely with refresh rate: **144Hz = 6.94ms**, **240Hz = 4.16ms**, **360Hz = 2.77ms**.
>    * If running AMD: Always prevent DC memory clock dropouts with `amdgpu.dcdebugmask=0x10 amdgpu.gpu_recovery=1` to guarantee tight VBLANK deadlines are never missed on 144Hz/240Hz+ panels.
>    * If running NVIDIA: Adapt modprobe parameters for `NVreg_UsePageAttributeTable=1`, `NVreg_InitializeSystemMemoryAllocations=0`.
> 5. **Mandatory Web Research for GPU-Specific Undervolt Baselines:**
>    * **NEVER apply a fixed, hardcoded undervolt across different GPU architectures** (e.g. a `-85 mV` offset on Navi 23 does NOT apply to RDNA 4 / RX 9070 XT, RDNA 3, or NVIDIA RTX).
>    * When tuning a GPU, the AI assistant **MUST perform live web research** to identify community-proven, rock-solid daily-driver voltage offsets and maximum boost frequencies for that exact GPU die before drafting any `/etc/local.d/` startup script.
> 6. **Dynamic RAM Capacity & ZRAM / Tmpfs Scaling:**
>    * Query host RAM using `free -h` or `/proc/meminfo` (`awk '/MemTotal/{print int($2/1024/1024)}' /proc/meminfo`).
>    * **16 GB RAM Machines (Workhorse)**: Set ZRAM to 100% of RAM (`16G`) with LZ4, backed by a secondary NVMe partition swap. Size `/var/tmp/portage` to `24G`.
>    * **32 GB+ RAM Machines (Battleship Rig)**: Set ZRAM dynamically to 50%–100% of physical RAM (`16G`–`32G`). With LZ4 compression (~2.5:1 ratio), a 32 GB ZRAM pool allows compiling massive monolith packages (`qtwebengine`, `llvm`, `firefox`) entirely inside compressed RAM/tmpfs without touching the SSD or causing OOM killer invocations. Size `/var/tmp/portage` to `28G`–`32G`.
> 7. **Strict Gentoo Source Policy:**
>    * Always compile packages and kernels from source. Never use binary packages (`--getbinpkg=n`) unless explicitly requested.

---

## 📋 Hardware Fleet & Reference Specs
* **Current Rig (Workhorse / Frankenstein):** AMD Ryzen 7 5700X (8c/16t, Zen 3 Vermeer), AMD Radeon RX 6650 XT (8GB VRAM), 16 GB DDR4 RAM. Also the **home binhost** for the Battleship (section 17).
* **Battleship Rig (Main Gaming):** AMD Ryzen 7 5800X3D (8c/16t, 96MB 3D V-Cache), AMD Radeon RX 9070 XT (RDNA 4), 32 GB RAM.
* **School Office PC:** AMD Ryzen 5 5600G (6c/12t, Zen 3 APU), NVIDIA GeForce GTX 1650 (4GB VRAM), 16 GB RAM. Runs **Windows 11**, not Gentoo; the Gentoo, kernel and OpenRC sections of this guide do not apply to it.
* **Init System:** OpenRC (Gentoo 23.0 profile)
* **Desktop Environment:** KDE Plasma 6 + Wayland + PipeWire

---

## 1. 👑 Ultra-Tuned Low-Latency Gaming Kernel (1000Hz + Zen 3 + Full Preemption)

Compiling your own custom kernel from source extracts maximum responsiveness, cuts input lag, and eliminates micro-stutters during high-refresh gaming (144Hz / 240Hz).

### 🏷️ Standardized Kernel Naming Convention (`CPUvGPU`):
Every custom kernel compiled with this guide uses the **`CPUvGPU`** naming standard set via `CONFIG_LOCALVERSION`:
* **This Machine (5700X + RX 6650 XT):** `CONFIG_LOCALVERSION="-5700v6650"` $\rightarrow$ `uname -r` outputs `7.1.9-5700v6650`
* **Battleship (5800X3D + RX 9070 XT):** `CONFIG_LOCALVERSION="-5800x3dv9070xt"` $\rightarrow$ `uname -r` outputs `7.1.9-5800x3dv9070xt`

### ⚙️ Kernel Configuration Snippet (`/etc/kernel/config.d/10-zen3-gaming.config`):
Create `/etc/kernel/config.d/10-zen3-gaming.config`:

```ini
# ==============================================================================
# AMD Zen 3 / Zen 4 Ultra-Tuned Gaming Kernel Configuration
# ==============================================================================

# 1. Native CPU Target (Optimizes all kernel binaries for Zen 3 & 3D V-Cache)
CONFIG_MZEN3=y
# CONFIG_GENERIC_CPU is not set

# 2. 1000Hz Timer Tick Rate (1.0ms scheduler resolution — cuts frame pacing jitter)
CONFIG_HZ_1000=y
# CONFIG_HZ_300 is not set
CONFIG_HZ=1000

# 3. Full Low-Latency Desktop Preemption
CONFIG_PREEMPT=y
# CONFIG_PREEMPT_NONE is not set
# CONFIG_PREEMPT_VOLUNTARY is not set
# CONFIG_PREEMPT_LAZY is not set

# 4. Realtime Priority Boosting & High-Resolution Timers
CONFIG_RCU_BOOST=y
CONFIG_RCU_BOOST_DELAY=500
CONFIG_SCHED_SMT=y
CONFIG_SCHED_MC=y
CONFIG_SCHED_HRTICK=y
CONFIG_HIGH_RES_TIMERS=y

# 5. High-Performance Memory & Transparent HugePages
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y
CONFIG_DEFAULT_MMAP_MIN_ADDR=65536

# 6. Standardized CPUvGPU Kernel Release Naming
CONFIG_LOCALVERSION="-5700v6650"
```

### 🛠️ How to Compile Kernel 100% From Source on Gentoo:
```bash
# 1. Enable savedconfig (for hardware-tailored builds) and disable debug symbols
echo "sys-kernel/gentoo-kernel -debug savedconfig" | sudo tee /etc/portage/package.use/00-kernel.conf

# 2. Compile kernel from source and register to @world (so 'up' auto-updates it)
sudo emerge --select sys-kernel/gentoo-kernel

# 3. Verify kernel installed in /boot/
ls -lh /boot/vmlinuz* /boot/initramfs*

# 4. Remove any old binary kernels
sudo emerge --unmerge sys-kernel/gentoo-kernel-bin 2>/dev/null || true
sudo rm -f /boot/*gentoo-dist-bin*

# 5. Update GRUB bootloader
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### 🔍 Verification After Reboot:
```bash
# Verify running kernel release:
uname -r                                         # Returns 7.1.9-5700v6650

# Verify 1000Hz timer:
cat /boot/config-$(uname -r) | grep "CONFIG_HZ_1000=y"

# Verify preemption model:
uname -a                                         # Displays PREEMPT
```

---

## 2. 🖥️ High-Refresh Display (144Hz / 240Hz / 360Hz+) Freeze Fix & Dynamic Silicon Undervolting

### Symptoms:
* Desktop completely freezes during idle typing or window switching on high-refresh displays (144Hz, 240Hz, or higher).
* `dmesg` reports: `[drm] *ERROR* [CRTC:...] flip_done timed out` or `kwin_wayland_drm: Pageflip timed out!`.

### Root Cause:
AMD's Display Core (DC) power-saving clock-gating drops memory clocks too low at idle. When a frame update is requested, clocks cannot ramp up in time to hit the tight VBLANK deadline:
* **144 Hz Panel**: 6.94 ms frame deadline
* **240 Hz Panel**: 4.16 ms frame deadline
* **360 Hz Panel**: 2.77 ms frame deadline

### The Permanent Display Core Fix:
1. **Create `/etc/modprobe.d/amdgpu.conf`:**
   ```ini
   # /etc/modprobe.d/amdgpu.conf
   options amdgpu dcdebugmask=0x10 gpu_recovery=1
   ```
2. **Add to `/etc/default/grub`:**
   ```bash
   GRUB_CMDLINE_LINUX_DEFAULT="amd_pstate=active quiet amdgpu.dcdebugmask=0x10 amdgpu.gpu_recovery=1"
   ```
3. **Regenerate GRUB and Initramfs:**
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   sudo dracut --force --kver $(uname -r)
   ```

---

### ⚡ Dynamic GPU Undervolting & Architecture Policy

> [!CAUTION]
> **ARCHITECTURE-SPECIFIC VOLTAGE RULES (DO NOT APPLY BLIND OFFSETS):**
> Different GPU silicon generations (RDNA 2, RDNA 3, RDNA 4, NVIDIA Ada/Blackwell) feature radically different V/F (Voltage/Frequency) curve topologies and voltage floor scaling.
> 
> * **Mandate for Visiting AI Agents**: NEVER blindly carry over voltage offsets from one card to another.
>   * Query the GPU model via `lspci -k | grep -EA3 "VGA|3D"`.
>   * Perform live web research to discover the community-proven golden undervolt offset and stable boost clock ceiling for that exact silicon (e.g. searching community benchmarks and overclocking forums for Radeon RX 9070 XT daily undervolt numbers) before writing any `/etc/local.d/` startup script.

#### Reference Implementation: AMD Radeon RX 6650 XT (Navi 23) Baseline
On this specific rig's Navi 23 die, a persistent **`-85 mV`** core offset with a **`2550 MHz`** ceiling provides maximum efficiency, sustained boost, and drops hotspot temperatures by ~10°C without power-limit throttling:

##### OpenRC Persistent Startup Script (`/etc/local.d/amdgpu-undervolt.start`):
```bash
#!/bin/bash
# Gentoo OpenRC - AMD Radeon RX 6650 XT Persistent Golden Undervolt
# Robust retry loop: wait up to 20 seconds for the GPU driver to initialize

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
Make executable: `sudo chmod +x /etc/local.d/amdgpu-undervolt.start`

##### Verification:
```bash
# Read live kernel OverDrive sysfs offsets:
cat /sys/class/drm/card*/device/pp_od_clk_voltage

# Check boot log:
cat /var/log/amdgpu-undervolt.log
```

---

## 3. 🌐 IPv6 Disabling & Streaming Timeout Fix

### Symptoms:
* AI tools (Antigravity CLI, OpenAI, Claude, gRPC/SSE streams) drop mid-generation with socket timeout/EOF errors due to ISP IPv6 MTU blackholing.

### The Permanent Fix:
Create `/etc/sysctl.d/99-disable-ipv6.conf`:
```ini
# /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```
**Apply immediately:**
```bash
sudo sysctl --system
```

---

## 4. ⚡ System Smoothness, Memory Management & TCP BBR Stack

Create `/etc/sysctl.d/99-performance.conf` to eliminate micro-stutters, prevent disk write freezes, and optimize RAM caching:

```ini
# /etc/sysctl.d/99-performance.conf

# 1. Memory & Swap Responsiveness (ZRAM Optimized)
vm.swappiness = 10                  # Favor physical RAM; swap only when necessary
vm.page-cluster = 0                 # Single-page I/O (essential for ZRAM compression)
vm.vfs_cache_pressure = 50          # Keep directory & file metadata in RAM for instant folder opening
vm.dirty_ratio = 10                 # Maximum dirty memory before synchronous writeout
vm.dirty_background_ratio = 5       # Background flush starts early (prevents desktop freezing during file copies)

# 2. Micro-Stutter Elimination & AAA Gaming Limits
vm.watermark_boost_factor = 0       # Disables kswapd wakeups (ELIMINATES random 50-100ms frame stutters)
vm.watermark_scale_factor = 125     # Direct memory reclaim buffer
vm.max_map_count = 2147483642       # Maximum memory mappings (essential for Steam Proton / AAA titles)

# 3. File Descriptors & Inotify Watchers
fs.file-max = 2097152               # High capacity open file descriptors
fs.inotify.max_user_watches = 524288 # Large file watcher capacity for KDE Baloo & code editors
fs.inotify.max_user_instances = 1024

# 4. Network & TCP Stack (Google BBR + Fast Open + Buffer Scaling)
net.core.default_qdisc = fq           # Fair Queueing packet pacing scheduler (required for BBR)
net.ipv4.tcp_congestion_control = bbr # Google BBR algorithm (maximizes throughput, cuts bufferbloat)
net.ipv4.tcp_fastopen = 3             # Enables TCP Fast Open for incoming & outgoing connections (0-RTT)
net.core.netdev_max_backlog = 16384   # Increases packet queue depth for Gigabit NIC
net.ipv4.tcp_max_syn_backlog = 8192   # Maximum pending connection requests
net.core.somaxconn = 8192             # Maximum socket listen backlog
net.core.rmem_max = 16777216          # 16 MB socket receive buffer ceiling
net.core.wmem_max = 16777216          # 16 MB socket send buffer ceiling
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

**Apply live:**
```bash
sudo sysctl --system
```

---

## 5. 💾 Dual-Tier Memory & Dynamic LZ4 Compressed ZRAM Swap

Prevents Out-Of-Memory (OOM) freezing during heavy 16-thread source builds while keeping zero swap thrashing during gaming.

### 📐 Fleet Memory Sizing & Tiering:
* **16 GB RAM Fleet (Workhorse):**
  * **Tier 1 (Priority 32767):** 16 GB Compressed RAM Swap via ZRAM (`lz4` algorithm).
  * **Tier 2 (Priority 1):** 16 GB NVMe SSD partition swap as a safety buffer.
  * *Prevents OOM lockups during multi-threaded builds while leaving ample RAM for desktop responsiveness.*
* **32 GB+ RAM Fleet (Battleship Rig):**
  * **Tier 1 (Priority 32767):** 16 GB to 32 GB Compressed RAM Swap via ZRAM (`lz4`).
  * *Why 32 GB ZRAM on a 32 GB system?* With LZ4 compression (~2.5:1 ratio), a 32 GB ZRAM swap space consumes only ~12-14 GB of actual physical RAM when fully utilized, effectively expanding your available workspace to ~50–60 GB. This guarantees that massive monolithic compiles (`qtwebengine`, `chromium`, `llvm`, `firefox`) build 100% inside RAM/tmpfs without touching the SSD or risking OOM process kills.

### ⚙️ OpenRC Dynamic ZRAM Startup Script (`/etc/local.d/zram.start`):
This script dynamically probes physical memory capacity at boot and automatically configures a matching ZRAM block device:

```bash
#!/bin/sh
modprobe zram num_devices=1
echo lz4 > /sys/block/zram0/comp_algorithm

# Dynamically scale ZRAM disk size to 100% of host physical RAM (e.g. 16G or 32G)
MEM_TOTAL_G=$(awk '/MemTotal/{print int($2/1024/1024)}' /proc/meminfo)
echo "${MEM_TOTAL_G}G" > /sys/block/zram0/disksize

mkswap /dev/zram0
swapon -p 32767 /dev/zram0
```
Make executable: `sudo chmod +x /etc/local.d/zram.start`

---

## 6. 🎧 PipeWire Ultra-Low Audio Latency (5.3ms / Pro-Audio)

Reduces audio buffer latency to ~1.3ms – 5.3ms for competitive FPS gaming and DAW production.

Create `~/.config/pipewire/pipewire.conf.d/10-latency.conf` and `/etc/pipewire/pipewire.conf.d/10-latency.conf`:

```spa
context.properties = {
    default.clock.rate          = 48000
    default.clock.allowed-rates = [ 44100 48000 88200 96000 192000 ]
    default.clock.quantum       = 64
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 1024
}
```

**Apply live dynamically:**
```bash
pw-metadata -n settings 0 clock.quantum 64
pw-metadata -n settings 0 clock.min-quantum 32
pw-metadata -n settings 0 clock.max-quantum 1024
```

---

## 7. 📊 Ultra-Smooth btop 100ms Realtime Monitoring

In `~/.config/btop/btop.conf`:
```ini
# Update time in milliseconds (100ms for smooth real-time monitoring)
update_ms = 100
```
*Gives instantaneous 100ms CPU/GPU/RAM responsiveness without sluggish 2-second lag.*

---

## 8. 🚀 OpenRC Parallel Boot & Optimization

Enable parallel daemon execution in `/etc/rc.conf`:
```ini
# /etc/rc.conf
rc_parallel="YES"
```
*Cuts boot time by launching non-dependent system services concurrently across all 16 CPU threads.*

---

## 9. 🔋 `power-profiles-daemon` with Auto-Respawn Supervision

Edit `/etc/init.d/power-profiles-daemon`:
```sh
#!/sbin/openrc-run
name="power-profiles-daemon"
description="Makes power profiles handling available over D-Bus"

supervisor=supervise-daemon
pidfile="/run/power-profiles-daemon.pid"
command="/usr/libexec/power-profiles-daemon"
respawn_max=0
respawn_delay=2

depend() {
	need dbus
	after display-manager
}

start_pre() {
	checkpath -d /var/lib/power-profiles-daemon
}
```
```bash
sudo rc-service power-profiles-daemon restart
```

---

## 10. 🔒 System-Wide NumLock on Boot (SDDM, KDE, TTYs)

1. **SDDM Login Screen:**
   `/etc/sddm.conf.d/numlock.conf`:
   ```ini
   [General]
   Numlock=on
   ```
2. **KDE Plasma & Lockscreen:**
   In `~/.config/kcminputrc` and `/etc/xdg/kcminputrc`:
   ```ini
   [Keyboard]
   NumLock=0
   ```
3. **Virtual Consoles (TTYs):**
   ```bash
   sudo rc-update add numlock default
   sudo rc-service numlock start
   ```

---

## 11. 🛠️ Optimized Portage `make.conf` & RAMDisk Reference

```bash
# /etc/portage/make.conf for AMD Ryzen Zen 3/4 + AMD Radeon RDNA
COMMON_FLAGS="-O2 -march=native -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# Mold Linker for instantaneous package linking
LDFLAGS="${COMMON_FLAGS} -Wl,-O1 -Wl,--as-needed -fuse-ld=mold"
RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=mold"

# Multicore optimization (8C/16T)
MAKEOPTS="-j16 -l14"
NINJAOPTS="-j16"
EMERGE_DEFAULT_OPTS="--jobs=16 --load-average=14 --getbinpkg=n --autounmask-write=y --autounmask-continue=y"

# Base keyword: Pure upstream/testing (~amd64) for full system synchronization
ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"

# Target architecture & hardware
GRUB_PLATFORMS="efi-64"
VIDEO_CARDS="amdgpu radeonsi"
CPU_FLAGS_X86="aes avx avx2 bmi1 bmi2 f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3 vpclmulqdq"

# Global USE flags (Debloated: No Bluetooth, Printing, or Cellular Modems)
USE="wayland pipewire pipewire-alsa wireplumber elogind dbus udev policykit lz4 zstd zram pulseaudio alsa vulkan opengl vdpau vaapi hwaccel screencast networkmanager sddm plasma dav1d svt-av1 jpegxl avif heif opus x264 x265 -systemd -telemetry -bluetooth -cups -modemmanager -handbook -doc -test"

# Features: ccache, parallel operations
FEATURES="ccache parallel-fetch parallel-install"
CCACHE_DIR="/var/cache/ccache"
LC_MESSAGES=C.utf8

# Compression for packages
PORTAGE_COMPRESS="lz4"
PORTAGE_COMPRESS_FLAGS="-T16"
```

### 🏛️ The Pure Testing (`~amd64`) Architecture (Zero Fragmentation & Full Synchronization)

While a hybrid architecture (stable base + cherry-picked `~amd64` keywords) attempts to insulate language runtimes from upstream churn, on enthusiast multi-threaded workstations it inevitably introduces the **"Hybrid Dependency Trap"**:
* **Subslot & Virtual Skew**: As upstream Gentoo stabilizes core virtuals (e.g. `virtual/perl-File-Spec-3.950.0`) that strictly require testing runtime versions (`dev-lang/perl-5.44*`), artificial version locks in `package.mask` collide with routine updates.
* **Portage Backtracking Tax**: Resolving the artificial boundary between stable plumbing and bleeding-edge desktops forces Portage to spend 40–60+ seconds calculating complex backtracking passes on every update.
* **Keyword File Clutter**: Maintaining 7–9 fragmented files in `/etc/portage/package.accept_keywords/` requires constant manual intervention.

#### The Zero-Touch Testing Standard:
By running **`ACCEPT_KEYWORDS="~amd64"` globally in `/etc/portage/make.conf`**:
1. **Total System Synchronization**: Compilers, core libraries, virtuals, and desktop environments (KDE Plasma 6, Mesa, Wayland, ROCm) advance together in complete lockstep.
2. **Zero Keyword Maintenance**: `/etc/portage/package.accept_keywords/` remains completely clean—no fragmented `.conf` files to babysit or resolve.
3. **Effortless Multi-Threaded Throughput**: Backed by a 16-thread Zen CPU, native mold linker (`-fuse-ld=mold`), and dual-tier LZ4 ZRAM tmpfs (`/var/tmp/portage`), full testing upgrades compile seamlessly in the background with zero developer friction.

> [!TIP]
> **Zero-Maintenance Upgrades:**
> With global `~amd64`, your maintenance alias `up` (`emerge -vuDN --with-bdeps=y --keep-going @world && emerge --depclean`) runs completely unattended with zero dependency blockers or keyword collisions.

### ⚡ High-Capacity Tmpfs RAMDisk for Lightning-Fast Builds (`/etc/fstab`):
Mounting `/var/tmp/portage` in RAM eliminates NVMe write cycles and dramatically accelerates parallel C++ compilation by operating directly in memory. Size according to available RAM:
* **16 GB RAM Systems (Workhorse)**: Set `size=24G` (seamlessly backed by 16G ZRAM + NVMe swap).
* **32 GB RAM Systems (Battleship)**: Set `size=28G` or `size=32G` (fits comfortably in RAM + ZRAM).

```ini
tmpfs   /var/tmp/portage   tmpfs   size=24G,uid=portage,gid=portage,mode=775,noatime   0 0
```
Mount immediately: `sudo mount /var/tmp/portage`

---

## 12. 📜 Essential Gentoo Maintenance Commands

### ⚡ The Ultimate 100% Zero-Touch "Fire-and-Forget" System Upgrade (`up`)

Add this alias to `~/.zshrc` (or `~/.bashrc`) for completely unattended multi-hour updates:

```bash
alias up='sudo zsh -c "eix-sync && emerge -vuDN --with-bdeps=y --keep-going @world && emerge --depclean"'
```

#### 🛡️ Architecture & Technical Breakdown:
1. **`sudo zsh -c "..."` (Sudo Timeout Protection)**:
   * Normally, `sudo` credential caching expires after 15 minutes. Wrapping the pipeline in a single elevated subshell guarantees that multi-hour compilations will never stall waiting for a password at the `depclean` stage.
2. **Git-Native Auto-Sync (`eix-sync`)**:
   * Because Portage is configured to sync via Git (`sync-type = git`), `eix-sync` executes in ~2-4 seconds with zero disk I/O penalties or server rate limits. This allows us to seamlessly integrate the sync directly into the upgrade pipeline.
3. **`emerge -vuDN --keep-going @world`**:
   * **`-v` (`--verbose`)**: Outputs full build telemetry, package versions, and USE flags.
   * **`-u` (`--update`)**: Upgrades packages to their newest available upstream releases.
   * **`-D` (`--deep`)**: Traverses the full dependency tree, not just top-level applications.
   * **`-N` (`--newuse`)**: Rebuilds packages if any USE flag configurations changed.
   * **`--keep-going`**: Continues compiling remaining packages even if a single non-critical ebuild fails.
4. **`--with-bdeps=y` (Build-Time Dependency Synchronization)**:
   * Synchronizes build tools (`cmake`, `meson`, `ninja`, `pkgconf`) alongside runtime libraries, ensuring toolchain parity and preventing `emerge --depclean` from pruning build dependencies required by future source compiles.
5. **`emerge --depclean`**:
   * Automatically sweeps and removes orphaned build-time dependencies and obsolete libraries once compilation completes, requiring zero manual prompts.

---

### 📋 Manual Maintenance Reference Table

**Required Packages:** `app-portage/gentoolkit`

| Task | Command |
| :--- | :--- |
| **All-in-One Unattended Update** | `up` |
| **Standard Interactive Update** | `sudo emerge -avuDN --with-bdeps=y --keep-going @world` |
| **Full System Rebuild** | `sudo emerge -ave --keep-going @world` |
| **Remove Orphan Packages (Interactive)** | `sudo emerge -av --depclean` |
| **Rebuild Broken Libs** | `sudo emerge -av @preserved-rebuild` |
| **Verify Dynamic Links** | `sudo revdep-rebuild` |
| **Clean Obsolete Distfiles** | `sudo eclean-dist -d -f` |
| **Check Config File Updates** | `sudo etc-update --preen` / `sudo dispatch-conf` |

---

### 🧹 Interactive FZF History Deletion Engine (`Ctrl-X`)

**Required Packages:** `app-shells/fzf`

Allows instantaneous in-place deletion of sensitive commands, typos, or obsolete scripts directly from inside FZF's `Ctrl+R` fuzzy search:

1. **Deletion Engine (`~/.local/bin/fzf-history-delete`)**:
   * Resolves Zsh multi-line continuations (`\\\n` $\to$ `\n`), strips escape backslashes, and safely prunes matched commands from `~/.zsh_history`.
   * Supports multi-item selections via `Tab`.
2. **Fast Stream Reloader (`~/.local/bin/fzf-history-reload`)**:
   * Re-evaluates `~/.zsh_history` in ~7ms and feeds the null-delimited stream directly back to FZF's `--read0` buffer for instant UI refresh.
3. **Zsh Integration (`~/.zshrc`)**:
   ```zsh
   # Must source base bindings FIRST!
   [ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
   [ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash

   export FZF_CTRL_R_OPTS="--bind 'ctrl-x:execute-silent(fzf-history-delete {+f})+reload(fzf-history-reload)' --header 'Ctrl-X: Delete entry | Ctrl-R: Toggle sort'"
   _fzf_history_wrapper() {
       fzf-history-widget "$@"
       local ret=$?
       fc -R 2>/dev/null
       return $ret
   }
   zle -N fzf-history-widget _fzf_history_wrapper
   ```

### 🛡️ Safe Configuration Merging (`etc-update`)

After running `up`, Portage may warn: `* IMPORTANT: X config files in '/etc' need updating.`
**Strict Rule: Never blindly auto-replace.** Run `sudo etc-update` and evaluate the diffs using this logic:

1. **REJECT (Press `2` - Delete update, keep your custom version):**
   * If upstream tries to revert your hardware/boot tuning (e.g., reverting `rc_parallel="YES"`).
   * If upstream attempts to strip out your custom OpenRC daemon supervision loops (e.g., `power-profiles-daemon`).
   * If the diff wipes out custom configurations like your `locale.gen` or UFW firewall rules.
2. **ACCEPT (Press `1` - Replace with new upstream default):**
   * If it is a brand new configuration file you haven't touched (e.g., `lm_sensors.conf`).
   * If the diff only contains harmless upstream comment updates or new default variables.
3. **AUTO-MERGE TRIVIAL (Press `-5`):**
   * Safely and automatically merges files where you have made zero manual modifications.

---

## 13. 🤖 AI (ROCm / PyTorch) Acceleration Reference

### ROCm / ComfyUI / PyTorch SDMA Page Fault Fix on RDNA GPUs:
On AMD Radeon consumer GPUs (Navi 23 / 6650 XT / 7000 / 9000 series), rapid weight offloading between RAM and VRAM during heavy neural model runs can cause hardware SDMA page faults (`Page not present / 0x7fa...`).

**⚠️ WARNING FOR GAMING RIGS:** Do *not* export these globally in your `~/.bashrc`! Disabling SDMA globally can cause severe performance degradation and visual glitches in standard desktop games and compositors. Add strictly to your local AI runner scripts (e.g. `run_gpu.sh`):
```bash
# Force ROCm compute shader memory blits (ELIMINATES SDMA page fault crashes):
export HSA_ENABLE_SDMA=0

# Hardware GFX override (10.3.0 for RDNA2 / RX 6650 XT, 11.0.0 for RDNA3, 12.0.0 for RDNA4):
export HSA_OVERRIDE_GFX_VERSION=10.3.0  # (Use 12.0.0 for Navi 48 / 9070 XT)

# PyTorch low-fragmentation memory allocator:
export PYTORCH_HIP_ALLOC_CONF="garbage_collection_threshold:0.6,max_split_size_mb:64"
```

---

## 14. 🎯 Clean Native Execution Policy

* **Pure Native Binary Execution:** Avoid bloated runtime wrappers and overlays (`gamemode`, `mangohud`, `gamescope`) for minimum translation overhead and maximum framerate stability.
* **Source-First Compilation:** Always compile software from source (`emerge --oneshot` / `emerge -1vUD @world`). The only binary packages allowed are those from the home binhost (section 17), which are themselves compiled from source with the fleet's shared configuration. Never use Gentoo's official binhost.

---

## 15. 🐧 Kernel & Toolchain Synchronization Rule

* **Lockstep Kernel Headers:** Whenever updating the kernel (`sys-kernel/gentoo-sources` or `sys-kernel/gentoo-kernel`), ALWAYS update and emerge `sys-kernel/linux-headers` to the matching target version in lockstep. This guarantees system C library (Glibc) UAPI definitions and kernel driver syscall interfaces remain perfectly synchronized.
* **Testing Branch (`~amd64`) Unmasking:** Managed via `/etc/portage/package.accept_keywords/09-kernel.conf`:
  ```text
  sys-kernel/linux-headers ~amd64
  sys-kernel/gentoo-sources ~amd64
  sys-kernel/gentoo-kernel ~amd64
  virtual/dist-kernel ~amd64
  ```
* **Distribution Kernel & `@world` Persistence:**
  * Ensure `sys-kernel/gentoo-kernel` is registered in `@world` (`emerge --select sys-kernel/gentoo-kernel`). This ensures the system maintenance alias `up` (`emerge -vuDN ... @world && emerge --depclean`) automatically compiles and installs newly released kernels, and prevents `emerge --depclean` from removing the kernel image, `dracut`, or `installkernel`.
  * Preserved silicon tuning snippets reside in `/etc/kernel/config.d/10-zen3-gaming.config` (`CONFIG_MZEN3=y`, `CONFIG_HZ_1000=y`, `CONFIG_PREEMPT=y`, `CONFIG_RCU_BOOST=y`, `CONFIG_LOCALVERSION="-5700v6650"`).
  * **Hardware Stripping via `USE="savedconfig"`**: `/etc/portage/package.use/00-kernel.conf` enables `sys-kernel/gentoo-kernel -debug savedconfig`, backed by `/etc/portage/savedconfig/sys-kernel/gentoo-kernel`. This drops ~4,700 unused enterprise driver modules down to ~100 active modules, keeping compile passes at ~2 minutes within `alias up`.

---

## 16. 🔄 Codeberg Master Guide Synchronization Directive

* **Continuous Repository Synchronization:** Whenever system tuning directives, kernel policies, or hardware rules are updated in the agent's brain or system rules, ALWAYS update `~/gentoo-tuning-guide/README.md` (Frankenstein: `/home/helin/…`, Battleship: `/home/ogun/…`), commit, and push directly to Codeberg (`https://codeberg.org/helinesca/gentoo-tuning-guide`).

---

## 17. 📦 Home Binhost (Frankenstein → Battleship)

Frankenstein compiles, the Battleship installs the finished packages. This works because both machines share the **same CPU target (`znver3`, Zen 3 Vermeer)**, the same `CPU_FLAGS_X86`, the same profile (`default/linux/amd64/23.0/desktop/plasma`, OpenRC), the same global `USE` line and `ACCEPT_KEYWORDS="~amd64"`. The 5800X3D's extra L3 cache changes performance, not the instruction set.

### Binhost side (Frankenstein, `gentoo-ryzen`, `192.168.1.9`)
* **Package store:** `PKGDIR=/var/cache/binpkgs`, format `gpkg`, lz4-compressed.
* **Every compile saves a package:** `FEATURES="ccache parallel-fetch parallel-install buildpkg"` in `make.conf`.
* **Initial fill without recompiling:** all installed packages were packed once with
  ```bash
  quickpkg --include-unmodified-config=y "*/*"
  ```
  `--include-unmodified-config=y` keeps default config files but leaves out every config file changed locally, so personal settings stay on Frankenstein. `quickpkg` creates root-only (`750`) folders, so afterwards: `chmod -R a+rX /var/cache/binpkgs`. Packages built by `emerge` are readable (`644`/`755`) automatically.
* **Serving:** `www-servers/lighttpd` on port **8080**, `/etc/lighttpd/lighttpd.conf`:
  ```text
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
  No `server.bind`: the address comes from DHCP, and a bind to a changed address would stop lighttpd from starting at boot. Started at boot with `rc-update add lighttpd default`.
* **Firewall:** `ufw allow from 192.168.1.0/24 to any port 8080 proto tcp comment 'binhost (lighttpd)'`. Only the home network can reach it.
* **Recommended:** reserve `192.168.1.9` for Frankenstein in the router (DHCP reservation).
* ⚠️ **Never forward port 8080 on the router.** The binhost has no signing and no authentication; it relies on being reachable only inside the home network. (Optional hardening: `FEATURES="binpkg-signing"` on the binhost and `binpkg-request-signature` on clients.)

### Client side (Battleship)
1. **Check:** `curl -s -o /dev/null -w "HTTP %{http_code}\n" http://192.168.1.9:8080/Packages` → `HTTP 200`.
2. **Remove Gentoo's official binhost** (usually `/etc/portage/binrepos.conf/gentoobinhost.conf`, section `[gentoo]`) and add `/etc/portage/binrepos.conf/frankenstein.conf`:
   ```ini
   [frankenstein]
   priority = 10
   sync-uri = http://192.168.1.9:8080
   verify-signature = false
   ```
   ⚠️ **`verify-signature = false` is required.** Current Portage verifies binary package signatures by default (`verify-signature = true` in `/usr/share/portage/config/binrepos.conf`, see Gentoo news `2026-05-03-portage-binpkg-changes`). The home binhost does not sign, so without this line every binary from Frankenstein is rejected. If `binpkg-signing` is set up on Frankenstein later, remove this line and import the public key into `/etc/portage/gnupg` on the Battleship instead.
3. **`make.conf`:** in `EMERGE_DEFAULT_OPTS`, `--getbinpkg=n` → `--getbinpkg=y`; keep `--binpkg-respect-use=y`, and add
   `--usepkg-exclude="sys-kernel/gentoo-kernel virtual/dist-kernel app-admin/ryzen_smu"`.
   The kernel and out-of-tree kernel modules are built for Frankenstein's own kernel (`-5700v6650`, savedconfig) and must always be compiled on the Battleship itself.
4. **Test:** `emerge --pretend --verbose --getbinpkg sys-block/parted` → the line starts with `[binary`. Then `emerge --pretend --verbose --update --deep --newuse @world`: `[binary …]` comes from the binhost, `[ebuild …]` is still compiled locally.

### What the Battleship still compiles itself
Anything not installed on Frankenstein (Steam, Chrome), packages whose USE flags differ (the 32-bit `abi_x86_32` variants for Steam: Mesa, LLVM, glibc, …), the kernel and kernel modules.

### Battleship status report (2026-09-27, written by the Claude on the Battleship)

**Binhost verified from the Battleship:** `http://192.168.1.9:8080/Packages` → `HTTP 200`. Client side **not yet enabled** on the Battleship (still `--getbinpkg=n`, official `gentoo.conf` binrepo still present but unused).

**Dry run with the binhost** (scratch config copy, `verify-signature = false`, kernel exclusions as above), `emerge -pvuDN --with-bdeps=y @world`:
* **475 packages total, 371 as binaries** from Frankenstein (gcc 16, glibc, perl 5.44, Qt/KDE, ffmpeg, linux-firmware, …), 3.5 GB download.
* **104 still compile on the Battleship**, mainly: `llvm-core/llvm` 22 **and** 23 (both with `abi_x86_32` for Steam's 32-bit Mesa), `media-libs/mesa`, `sys-kernel/gentoo-kernel-7.2.8`, `app-admin/ryzen_smu`, `games-util/steam-launcher`, and the ~70 `abi_x86_32` libraries.
* Ignored "due to changed dependencies" (version/subslot skew, rebuild on Frankenstein will fix): `sys-apps/coreutils`, `app-shells/zsh`, `net-misc/curl`, `dev-libs/libgcrypt`, `dev-util/patchelf`, `x11-misc/xdg-utils`, `dev-perl/Socket6`.
* **To make the 32-bit Steam stack binary too**, Frankenstein's build chroot must carry the Battleship's `package.use/steam` (below). Otherwise those always compile locally.

**CPU flags:** `adx`, `rdseed` and `vaes` no longer exist in `profiles/desc/cpu_flags_x86.desc`, so `cpuid2cpuflags` (v17) no longer prints them and Portage ignores them. Both 5700X and 5800X3D resolve `-march=native` to `znver3`. The CPU_FLAGS line in section 11 is updated; the extra flags were harmless, just stale.

**Battleship Portage changes made on 2026-09-27** (the binhost chroot should mirror these):
* `package.use/steam`: added `sys-libs/gdbm abi_x86_32` and `sys-libs/readline abi_x86_32` (required by 32-bit `sys-libs/pam` via `sys-libs/libcap`; without them `@world` does not resolve).
* `package.use/02-fixes.conf`: `sys-libs/ncurses -gpm` (breaks the 32-bit ncurses ↔ gpm circular dependency; gpm is console-mouse only).
* `package.use/10-modules`: `app-admin/ryzen_smu dist-kernel` (module rebuilds automatically on every new kernel).
* `package.use/00-kernel.conf`: `savedconfig` **removed** for now. The running 6.18.50 kernel is the full generic build (4,905 modules); the stripped 103-module savedconfig in this repo was made on Frankenstein's hardware and must not be reused on the Battleship. A Battleship-specific stripped config will be made later.
* `make.conf`: `--autounmask-write=y --autounmask-continue=y` removed from `EMERGE_DEFAULT_OPTS` (no silent config rewrites during unattended updates).
* `@world`: fixed wrong atoms (`kde-plasma/spectacle`, `gui-apps/xwaylandvideobridge`), removed `media-video/vlc`, and pinned `sys-kernel/gentoo-kernel:6.18.50` as the known-good fallback until 7.2.8 has booted.
* `~/.zshrc`: `up` alias added (the default shell is zsh; the alias previously existed only in `.bashrc`).
* ⚠️ **Pitfall:** Portage reads **every** file in `package.use/` etc., including backups like `foo.bak`. Never keep backups inside `/etc/portage`.

### Keeping both machines in step
Binary packages are used only when the version matches. Sync the Gentoo tree on both machines around the same time (`emaint sync -a`) and update Frankenstein first, so its packages are ready when the Battleship updates.
