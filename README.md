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
>    * Target the build machine's own CPU in `/etc/kernel/config.d/10-zen3-gaming.config` with `CONFIG_X86_NATIVE_CPU=y` (`-march=native`). **Do not use `CONFIG_MZEN3`/`MZEN4`/`MZEN5`/`MCORE2`/`GENERIC_CPU`:** mainline removed these per-CPU options (6.18 has none of them), and Kconfig silently ignores them, leaving a generic x86-64 build.
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
* **Battleship Rig (Main Gaming):** AMD Ryzen 7 5800X3D (8c/16t, 96MB 3D V-Cache), AMD Radeon RX 9070 XT (RDNA 4, **Sapphire Nitro+**, PCI subsystem `1da2:e489`, 340 W board power, 12V-2x6 connector), 32 GB RAM.
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

# 1. Native CPU Target (-march=native for the machine that builds the kernel)
#    Mainline removed CONFIG_MZEN3 & co. (absent in 6.18); they are silently ignored.
CONFIG_X86_NATIVE_CPU=y

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
#    RCU_BOOST is only offered with RCU_EXPERT=y; without it both lines are dropped.
CONFIG_RCU_EXPERT=y
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

# Verify native CPU target and RCU boost really made it into the kernel:
zgrep -E 'CONFIG_X86_NATIVE_CPU=|CONFIG_RCU_BOOST=' /proc/config.gz
```

> ⚠️ Kconfig silently drops options that no longer exist or whose dependencies are not met. After every new kernel, compare each line of `/etc/kernel/config.d/*.config` with `/proc/config.gz`.

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


#### Reference Implementation: Sapphire Nitro+ RX 9070 XT (Navi 48 / RDNA 4), Battleship

**RDNA 4 uses offsets, not absolute clocks.** `pp_od_clk_voltage` on Navi 48 has **no max-clock state** (the RDNA 2 command `s 1 <MHz>` fails with `Invalid argument`). Instead it offers:
```text
OD_SCLK_OFFSET:   shift of the card's internal maximum GFX clock   range -500 .. +1000 MHz
OD_VDDGFX_OFFSET: voltage offset                                    range -200 .. 0 mV
OD_MCLK:          memory clock range                                97 .. 1500 MHz
```
Commands: `vo <mV>` (voltage offset), `s <MHz>` (clock offset, **one** number, no index), `c` (commit). Read back with `cat /sys/class/drm/card0/device/pp_od_clk_voltage`.

**The internal maximum is far above the advertised boost.** Nitro+ specs: game clock 2520 MHz (the top level shown in `pp_dpm_sclk`), boost "up to 3060 MHz". Measured under full load: **3307 MHz** at stock clocks with -60 mV, power-limited at 347 W. Working back from the capped runs, the internal maximum is **~3430 MHz**. So `offset = target − 3060` does **not** work; measure instead.

**How it was measured (no extra packages needed):** a full-screen WebGL2 fragment-shader loop in a throwaway Chrome profile (`google-chrome-stable --user-data-dir=<tmp> --ozone-platform=wayland file://…/gpuload.html`), sampling `hwmon/freq1_input`, `power1_average` and `temp1_input` every 0.2 s for 20 s. (`vkcube` would do as well, but `dev-util/vulkan-tools` needs `USE=cube` for it.)

| Setting | Peak clock | Average clock | Power (avg / peak) | Edge temp |
|---|---|---|---|---|
| -60 mV, no offset | 3307 MHz | 3213 MHz | ~347 W (power limit) | 48 °C |
| -100 mV, -407 MHz | 3023 MHz | 2970 MHz | 207 W / 244 W | 49 °C |
| **-100 mV, -500 MHz (daily)** | **2932 MHz** | **2882 MHz** | **236 W / 276 W** | 52 °C |

The target was -100 mV with a 2900 MHz ceiling. **-500 MHz is the driver's lower limit**, so ~2930 MHz is the lowest reachable cap on this card. Result: about 10 % less clock for **~110 W less** power. No `amdgpu` errors in `dmesg` during the tests.

##### OpenRC Persistent Startup Script (`/etc/local.d/amdgpu-undervolt.start`):
```bash
#!/bin/bash
# Gentoo OpenRC - Sapphire Nitro+ RX 9070 XT (Navi 48 / RDNA 4) undervolt + clock cap
# RDNA 4 has no absolute max-clock setting, only an offset from the card's internal
# maximum (~3430 MHz on this card). Driver range: SCLK_OFFSET -500..+1000 MHz,
# VDDGFX_OFFSET -200..0 mV. -500 MHz is the lowest allowed and caps boost at ~2930 MHz
# (measured 2026-09-27: avg 2882 MHz, peak 2932 MHz, ~236 W under full load).
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
Requires `amdgpu.ppfeaturemask=0xffffffff` on the kernel command line (already in the Battleship's GRUB line) so that OverDrive is writable.

**Stability:** a 20-second load test is not a stability proof. If a game crashes, or the screen freezes and the driver recovers (`amdgpu … ring … timeout` / `GPU reset` in `dmesg`), go back to `vo -80` first and keep `s -500`.

**No LACT on the Battleship.** An Ubuntu `.deb` copy of LACT had been dropped into `/usr/bin` without Portage. It never ran (missing `libadwaita-1.so.0` and `libdisplay-info.so.1`), and its OpenRC service `lactd` respawned every 2 s since boot. It was removed on 2026-09-27. The only ebuild (`sys-apps/lact` in GURU) is not an option: GURU is never used on this fleet, and it needs `libdisplay-info:0/3` anyway. The `/etc/local.d` script above covers everything that was needed.


---

### 🧠 Battleship CPU: Ryzen 7 5800X3D PBO, Curve Optimizer & CPPC

The 5800X3D's multiplier is locked, so the only real tuning is **Curve Optimizer (CO)**: a per-core shift of the voltage/frequency curve, set in the BIOS under *PBO → Curve Optimizer*. It needs a newer BIOS (AGESA 1.2.0.8 or later). Negative counts mean less voltage at the same clock, so cooler cores and longer boost. **PBO** itself only sets the power and current limits (PPT/TDC/EDC).

#### What can be read from Linux
* **PBO limits and live telemetry: yes.** `app-admin/ryzen_smu` (kernel module, `USE=dist-kernel` so it rebuilds for every new kernel) plus `app-admin/ryzen_monitor`: `sudo ryzen_monitor`.
* **Curve Optimizer counts: not reliably.** There is no documented read path. ZenStates-Core reads CO on Vermeer via RSMU command `0x7C` (`GetDldoPsmMargin`), but its own source marks the ID `// Not sure`, and neighbouring RSMU IDs **set** CO and PBO values. **Never send raw SMU commands on a guess.** Check CO in the BIOS instead.
* **CPPC core ranking: yes**, from sysfs (below).

#### Battleship values (read 2026-09-27, kernel 6.18.50-5800x3dv9070xt, SMU firmware 56.78.0)

**PBO limits** (`ryzen_monitor`, *Electrical & Thermal Constraints*):

| Limit | Value |
|---|---|
| PPT (package power) | 142 W |
| TDC (sustained current) | 95 A |
| EDC (peak current) | 130 A |
| THM (temperature limit) | 90 °C |

Under a 16-thread Portage compile: all cores at ~4440 MHz, ~96 W PPT (68 %), 60 A TDC, peak core voltage 1.239 V, **75–82 °C**. That is normal for a 5800X3D even with negative CO, because the V-Cache die on top of the cores traps heat. Memory: 1826 MHz FCLK = UCLK = MCLK, coupled 1:1 (DDR4-3650).

**Curve Optimizer** (set in the BIOS by the user and confirmed in the BIOS save summary), matched against the CPPC ranking from `/sys/devices/system/cpu/cpu*/acpi_cppc/highest_perf` (also `cpufreq/amd_pstate_prefcore_ranking`):

| Core | CPPC highest_perf | Rank | CO |
|---|---|---|---|
| 0 | 196 | 1 | -20 |
| 1 | 196 | 1 | -20 |
| 2 | 191 | 3 | -20 |
| 5 | 186 | 4 | -25 |
| 4 | 181 | 5 | -25 |
| 3 | 176 | 6 | -25 |
| 6 | 171 | 7 | -30 |
| 7 | 166 | 8 | -30 |

(CPUs 8–15 are the SMT siblings of cores 0–7 and share their values.) This is the recommended pattern: the **best-ranked cores get the mildest CO**, because they do the highest single-thread boosting and are the first to become unstable with large negative counts. The weakest cores tolerate the most.

**CO stability:** negative-CO instability shows up at **light, single-core loads** (idle, browsing), not in all-core compiles. If random reboots or crashes happen at idle, back off cores 6 and 7 to -25 first.

**amd_pstate / CPPC state:** `amd_pstate=active` (EPP mode), preferred-core enabled (`/sys/devices/system/cpu/amd_pstate/prefcore` = `enabled`), max frequency 4.55 GHz, nominal 3.4 GHz. Governor, EPP and power-profiles-daemon are all set to `performance`. The cores still reach deep sleep (C6 ~90 % at idle). `balanced` would lower idle power further at practically no gaming cost.

Read everything again with:
```bash
sudo ryzen_monitor                                                  # PBO limits + live telemetry
cat /sys/devices/system/cpu/amd_pstate/{status,prefcore}
for c in /sys/devices/system/cpu/cpu[0-7]; do echo "${c##*/} $(cat $c/acpi_cppc/highest_perf)"; done
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
| **Remove an Old Dist-Kernel** | `sudo emerge --deselect sys-kernel/gentoo-kernel:<ver>` (if pinned) → `sudo emerge --depclean '=sys-kernel/gentoo-kernel-<ver>'` → remove the leftover `/boot/{vmlinuz,initramfs,config,System.map}-<ver>…` and `/lib/modules/<ver>…` (not owned by any package, so depclean leaves them; `app-admin/eclean-kernel` automates this) → `sudo grub-mkconfig -o /boot/grub/grub.cfg` |

---

### 🐚 Zsh Shell Setup (prompt, history, completion, FZF `Ctrl-R` / `Ctrl-X`)

**Required Packages:** `app-shells/zsh` `app-shells/fzf` `dev-lang/perl` (fzf's `Ctrl-R` uses it for multi-line history), plus the extras `app-shells/zsh-completions` `app-shells/gentoo-zsh-completions` `app-shells/zsh-syntax-highlighting`.

Gentoo ships **no system-wide `zshrc`**. Without a `~/.zshrc`, zsh shows the bare `hostname%` prompt, keeps **no history file**, and has no completion menu. Making zsh the login shell (`chsh -s /bin/zsh`) is not enough on its own.

Reference files in this repo (copy them to `~`):
* [`home/.zshrc`](home/.zshrc): prompt `user@host ~/dir (git-branch) [exit code] %`, shared history in `~/.zsh_history` (100k entries, no duplicates, lines starting with a space are not saved), `compinit` with a menu, `~/.local/bin` in `PATH`, Home/End/Delete/Ctrl-arrow keys as Konsole sends them, Up/Down history search by prefix, the FZF integration below, the `up` alias, and syntax highlighting (must stay the **last** line).
* [`home/.local/bin/fzf-history-delete`](home/.local/bin/fzf-history-delete): the `Ctrl-X` deletion engine.

The prompt ends in `%` for a normal user and `#` for root (`%#`); this is zsh's equivalent of bash's `$`.

#### 🧹 FZF History Deletion Engine (`Ctrl-R`, then `Ctrl-X`)
Deletes the selected entries (multi-select with `Tab`) straight from the `Ctrl-R` list:
```zsh
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh

export FZF_CTRL_R_OPTS="--bind 'ctrl-x:execute-silent(fzf-history-delete {+f})+exclude-multi' --header 'Ctrl-X: Delete entry | Ctrl-R: Toggle sort'"
_fzf_history_wrapper() {
    fzf-history-widget "$@"
    local ret=$?
    local flag=${XDG_RUNTIME_DIR:-/tmp}/.zsh-history-edited-$UID
    if [[ -e $flag ]]; then
        # Drop the in-memory history and reload the pruned file
        rm -f -- $flag
        local hs=$HISTSIZE
        HISTSIZE=0; HISTSIZE=$hs
        fc -R
    fi
    return $ret
}
zle -N fzf-history-widget _fzf_history_wrapper
```
How it works, and why the first version did not:
* fzf's `{+f}` passes the **path of a temp file** holding the selected lines (`NUM<TAB>command`, extra lines of multi-line commands start with a TAB), not the command text. The old script treated the path as the command, so nothing was ever deleted, and its unescaped `sed` pattern could delete the wrong lines for commands containing `|` or regex characters.
* The new script is a `zsh -fi` script: zsh itself reads `~/.zsh_history` (`fc -R`), drops entries whose text matches exactly, and writes the file back (`fc -W`). This handles multi-line commands, non-ASCII text (zsh stores it metafied) and special characters. It needs `-i`, because a non-interactive zsh silently writes no history. It also works around `$history` lagging one entry behind by adding a dummy entry. Tested: 20,000 entries in about 1 s.
* `exclude-multi` (present in fzf 0.74, the version used here) removes the entries from the open list, so the event numbers of the other entries stay valid. `fzf-history-reload` is no longer used.
* `~/.local/bin` must be in `PATH` (it is, in `home/.zshrc`), or `Ctrl-X` fails silently.

#### ⚠️ Zsh pitfalls for Gentoo commands
* **Quote `=`-atoms:** in zsh, a word starting with `=` is replaced by a command path (`EQUALS`), so `emerge --depclean =sys-kernel/gentoo-kernel-6.18.50` fails with `sys-kernel/gentoo-kernel-6.18.50 not found`. Write `'=sys-kernel/gentoo-kernel-6.18.50'`.
* **Globs in root-only directories:** in `sudo rm /boot/*6.18.50*`, the `*` is expanded by *your* shell before `sudo`, and `/boot` is `drwx------ root`, so zsh stops with `no matches found`. Use exact file names, or `sudo zsh -c '...'`.
* **A leading `!` inverts the exit status** (`! cmd` → runs `cmd`, `[1]` on success). In `! a && b`, `b` never runs when `a` succeeds.

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

**The automatic modes** (from `/usr/bin/etc-update`): `-3` replaces **all** your files with the new defaults, `-5` does the same without `mv -i` prompts. **Never use either on this system.** `-7` **discards all updates** and keeps your files (it asks `rm: remove '._cfg…'?` per file; answer `y`), `-9` does the same after one `YES`. Files that differ only in comments are auto-merged by etc-update itself ("Automerging trivial changes").

**Real case (Battleship, 2026-09-28, after the 7.2.8 update):** the new `/etc/rc.conf` would have removed `rc_parallel="YES"`, `unicode`, `rc_tty_number=12` and `rc_shell`; the new `/etc/default/grub` would have removed the whole kernel command line (`amd_pstate=active`, `amdgpu.dcdebugmask=0x10`, `gpu_recovery=1`, `ppfeaturemask`). Both were rejected; `/etc/conf.d/hostname` was comments only and auto-merged.

---

## 12a. 📦 What to Install (Battleship Reference Package Set)

The Battleship's `@world` (`/var/lib/portage/world`, 2026-09-28), grouped by purpose. With the home binhost (section 17) almost all of it arrives as signed binaries; always check first with `emerge -pv <packages>` (`[binary …]` vs `[ebuild …]`). Use `--noreplace` when some of them may already be installed.

### 1. Prerequisites: install these first
The configs in this guide call these tools; without them builds, updates or boot scripts fail.

| Package | Needed by |
| :--- | :--- |
| `sys-devel/mold` | `LDFLAGS`/`RUSTFLAGS` use `-fuse-ld=mold` (section 11); without it every link fails |
| `dev-util/ccache` | `FEATURES="ccache"`, `CCACHE_DIR=/var/cache/ccache` |
| `app-portage/eix` | `eix-sync` in the `up` alias |
| `app-portage/gentoolkit` | `equery`, `revdep-rebuild`, `eclean-dist` (section 12) |
| `app-portage/cpuid2cpuflags` | generating `CPU_FLAGS_X86` |
| `app-admin/sudo`, `dev-vcs/git`, `app-eselect/eselect-repository` | the `up` alias, git sync, the `steam-overlay` repository |
| `sys-kernel/gentoo-kernel`, `sys-kernel/installkernel` (`USE="dracut grub"`), `sys-kernel/linux-firmware`, `sys-boot/grub` | kernel section 1; `installkernel` puts kernel + initramfs in `/boot` and runs `grub-mkconfig` |
| `app-arch/lz4` (pulled in by default) | `BINPKG_COMPRESS="lz4"` and the ZRAM script (section 5) |
| `sys-power/power-profiles-daemon` | section 9 |
| `sys-process/btop` | section 7 |
| `sys-process/cronie` (+ `rc-update add cronie default`) | runs `/etc/cron.daily` etc. (plocate database, man-db, tmpfiles cleanup). Gentoo installs **no cron daemon by default**, so without it these jobs never run. Its anacron catches up on jobs missed while the PC was off. `crontab -e` edits personal jobs |
| `app-shells/zsh`, `app-shells/fzf`, `dev-lang/perl` | login shell and `Ctrl-R`/`Ctrl-X` (section 12, *Zsh Shell Setup*) |
| `app-admin/ryzen_smu` (`USE=dist-kernel`), `app-admin/ryzen_monitor` | Battleship CPU telemetry (section 2); `ryzen_smu` is always built locally |

Portage settings these packages need (already in `etc/portage/package.use/` or described in section 17): `package.use/steam` with the `abi_x86_32` list (incl. `sys-libs/gdbm` and `sys-libs/readline`), `sys-libs/ncurses -gpm`, `app-admin/ryzen_smu dist-kernel`, `sys-kernel/gentoo-kernel -debug`.

### 2. Desktop base
`kde-plasma/plasma-meta` `x11-misc/sddm` `gui-libs/display-manager-init` `media-video/pipewire` `media-video/wireplumber` `net-misc/networkmanager` `kde-apps/konsole` `kde-apps/dolphin` `gui-apps/wl-clipboard` `gui-apps/xwaylandvideobridge` `kde-plasma/spectacle` `www-client/google-chrome`
Fonts: see *Fonts* below.

### 3. Everyday apps (needed: nothing else covers these)
| Package | Why |
| :--- | :--- |
| `media-video/mpv` | video player (`media-video/vlc` was removed) |
| `kde-apps/ark` `app-arch/7zip` `app-arch/unrar` `app-arch/zip` | archives in Dolphin (only `unzip` is there by default) |
| `kde-apps/kate` | GUI text editor |
| `kde-apps/okular` | PDF / document viewer |
| `kde-apps/gwenview` | image viewer |
| `kde-apps/ffmpegthumbs` `media-video/ffmpegthumbnailer` | video thumbnails in Dolphin (log out/in once) |
| `media-plugins/gst-plugins-meta` | GStreamer codecs for apps that use it |
| `sys-fs/dosfstools` `sys-fs/exfatprogs` `sys-fs/ntfs3g` | format / mount FAT, exFAT and NTFS drives |

### 4. Hardware & diagnostics
`sys-apps/pciutils` `sys-apps/usbutils` `dev-util/vulkan-tools` (`vulkaninfo`) `dev-util/clinfo` `media-video/libva-utils` (`vainfo`: on the RX 9070 XT, Mesa radeonsi decodes H.264, HEVC 10-bit and AV1 and encodes H.264/HEVC) `sys-process/nvtop` (GPU load, clocks, power; useful for the undervolt)
Board sensors need no package: the MSI MPG B550 GAMING PLUS's NCT6687D chip uses the in-kernel **`nct6683`** driver (`CONFIG_SENSORS_NCT6683=m`; `NCT6687` does not exist in mainline). It does not load by itself, so add `nct6683` to `/etc/modules-load.d/sensors.conf` (loaded by OpenRC's `modules` service). hwmon then shows `nct6687` with fans, board temperatures and voltages.

### 5. Gaming
`games-util/steam-launcher` from `steam-overlay` (`eselect repository enable steam-overlay`), with `package.use/steam`. The 32-bit (`abi_x86_32`) stack it needs (LLVM, Mesa, ~70 libraries) is compiled locally unless Frankenstein carries the same `package.use/steam`.

### 6. Shell extras
`app-shells/zsh-completions` `app-shells/gentoo-zsh-completions` (Tab completion for `emerge`, `eselect`, `rc-service`, …) `app-shells/zsh-syntax-highlighting` (source it on the last line of `~/.zshrc`) `app-shells/zoxide` (`z <part of a dir>` jumps to frequent directories; needs `eval "$(zoxide init zsh)"` in `~/.zshrc`, see `home/.zshrc`). `app-shells/zsh-autosuggestions` is not on the binhost (tiny compile).

### 7. Tools (installed on the Battleship)
| Package | What for |
| :--- | :--- |
| `app-admin/eclean-kernel` | `sudo eclean-kernel -n 2` keeps the newest two kernels and removes the rest incl. `/boot` and `/lib/modules` leftovers (needs root even for `-p`); pulls in ~9 small Python packages that compile locally |
| `sys-apps/plocate` | fast `locate`; its database is refreshed by `/etc/cron.daily/plocate-updatedb` (needs cronie). Fill it once by hand: `sudo updatedb` |
| `sys-apps/ripgrep` `sys-apps/fd` `sys-apps/bat` `sys-apps/eza` | faster `grep`, `find`, `cat` with highlighting, `ls` with colours/git |
| `app-misc/fastfetch` `sys-fs/duf` `net-misc/yt-dlp` | system summary, disk usage overview, video downloader |

### Fonts
The Battleship has **every real font from the Gentoo repo** (`media-fonts/*`, ~175 packages, ~1.2 GB, about half of it CJK: `noto-cjk` alone is 276 MB). Web pages, documents and games in any script show real characters instead of boxes. fontconfig defaults stay sensible: `sans-serif` → Liberation Sans, `monospace` → Liberation Mono, `emoji` → Noto Color Emoji.

Left out on purpose: tools (`bdf2sfd`, `pcf2bdf`, `font-util`, `encodings`, `font-alias`), the `fonts-meta` meta package, the test font `ahem`, and legacy X11 bitmap fonts (`font-*-75dpi/100dpi/misc/cyrillic`, `artwiz-*`, `dina`, `ohsnap`, `proggy-fonts`, `spleen`, `termsyn`, `unifont`, `intlfonts`, `wqy-bitmapfont`, …), which KDE on Wayland does not use and fontconfig hides by default. Rebuild the list with:
```bash
cd /var/db/repos/gentoo/media-fonts && ls | grep -vx metadata.xml | grep -vE '^(bdf2sfd|pcf2bdf|font-util|encodings|font-alias|fonts-meta|ahem|font-.*(75dpi|100dpi|-misc|cyrillic)|artwiz-.*|dina|ohsnap|proggy-fonts|spleen|termsyn|glass-tty-vt220|efont-unicode|shinonome|wqy-bitmapfont|wqy-unibit|x11fonts-jmk|lfpfonts-.*|jisx0213-fonts|intlfonts|sgi-fonts|cronyx-fonts|font-arabic-misc|unifont|mikachan-font-(ttc|ttf))$' | sed 's#^#media-fonts/#' > /tmp/fonts.txt
sudo emerge -av --noreplace --keep-going --jobs=1 $(cat /tmp/fonts.txt) && sudo fc-cache -f
```
* Fonts are not on the binhost (Frankenstein has no use for them), so they come from the Gentoo mirrors; only `media-gfx/fontforge` (needed to build a few fonts) really compiles.
* ⚠️ **Pitfall:** with `--jobs=16`, many font packages run `fc-cache` at the same time; one fails with `/usr/share/fonts: failed to write cache`, and without `--keep-going` emerge stops and skips the rest. Use `--jobs=1` (or `--keep-going`) and finish with `sudo fc-cache -f`.
* If emoji ever switch to the JoyPixels style, pin Noto Color Emoji with a fontconfig rule.

### 8. Not for the desktop
Frankenstein-only: `www-servers/lighttpd` (binhost server), `net-firewall/ufw` (its binhost firewall; the Battleship currently runs no firewall service, still to be decided), `sys-process/numactl`, `sci-libs/gsl`.

### One-shot install (Battleship, after the base system)
```bash
sudo emerge -av --noreplace \
  sys-devel/mold dev-util/ccache app-portage/eix app-portage/gentoolkit app-portage/cpuid2cpuflags \
  media-video/mpv kde-apps/ark app-arch/7zip app-arch/unrar app-arch/zip kde-apps/kate kde-apps/okular \
  kde-apps/ffmpegthumbs media-video/ffmpegthumbnailer sys-fs/dosfstools sys-fs/exfatprogs \
  media-video/libva-utils sys-process/nvtop sys-process/cronie \
  app-shells/zsh-completions app-shells/gentoo-zsh-completions app-shells/zsh-syntax-highlighting app-shells/zoxide \
  app-admin/eclean-kernel sys-apps/plocate sys-apps/ripgrep sys-apps/fd sys-apps/bat sys-apps/eza \
  app-misc/fastfetch sys-fs/duf net-misc/yt-dlp
sudo rc-update add cronie default && sudo rc-service cronie start && sudo updatedb
```
Then the fonts (above).

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
  * Preserved silicon tuning snippets reside in `/etc/kernel/config.d/10-zen3-gaming.config` (`CONFIG_X86_NATIVE_CPU=y`, `CONFIG_HZ_1000=y`, `CONFIG_PREEMPT=y`, `CONFIG_RCU_EXPERT=y` + `CONFIG_RCU_BOOST=y`, `CONFIG_LOCALVERSION="-5700v6650"`).
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
* ⚠️ **Never forward port 8080 on the router.** Packages are signed (see *Binary package signing*), but the server itself has no authentication and is meant for the home network only.

### Client side (Battleship)
1. **Check:** `curl -s -o /dev/null -w "HTTP %{http_code}\n" http://192.168.1.9:8080/Packages` → `HTTP 200`.
2. **Remove Gentoo's official binhost** (usually `/etc/portage/binrepos.conf/gentoobinhost.conf`, section `[gentoo]`) and add `/etc/portage/binrepos.conf/frankenstein.conf`:
   ```ini
   [frankenstein]
   priority = 10
   sync-uri = http://192.168.1.9:8080
   ```
   Signatures stay verified (the Portage default): Frankenstein signs every package, see *Binary package signing* below.
   ⚠️ **Never set `verify-signature = false`.** It would let any device on the LAN that impersonates `192.168.1.9` serve arbitrary packages installed as root. Trust the binhost's public key instead (below).
3. **`make.conf`:** in `EMERGE_DEFAULT_OPTS`, `--getbinpkg=n` → `--getbinpkg=y`; keep `--binpkg-respect-use=y`, and add
   `--usepkg-exclude="sys-kernel/gentoo-kernel virtual/dist-kernel app-admin/ryzen_smu"`.
   The kernel and out-of-tree kernel modules are built for Frankenstein's own kernel (`-5700v6650`, savedconfig) and must always be compiled on the Battleship itself.
4. **Test:** `emerge --pretend --verbose --getbinpkg sys-block/parted` → the line starts with `[binary`. Then `emerge --pretend --verbose --update --deep --newuse @world`: `[binary …]` comes from the binhost, `[ebuild …]` is still compiled locally.

### What the Battleship still compiles itself
Anything not installed on Frankenstein (Steam, fonts, Chrome is a binary anyway), packages whose USE flags differ (the 32-bit `abi_x86_32` variants for Steam: Mesa, LLVM, glibc, ~70 libraries), the kernel and kernel modules (`ryzen_smu`).

### Binary package signing
Every package on the binhost is signed; new `emerge`/`quickpkg` builds are signed automatically, and the Battleship verifies every download (Portage default).

| | |
|---|---|
| Key | `Frankenstein binhost <binhost@gentoo-ryzen.lan>`, ed25519, sign-only, no expiry |
| **Fingerprint** | **`8838 6760 B669 D0AD BC01  D926 EB26 C91F 3ABB 14F8`** |
| Public key | `http://192.168.1.9:8080/binhost-signing.asc` |
| Private key | `/root/.gnupg` on Frankenstein only (no passphrase, so unattended builds can sign; never copied anywhere) |

**Binhost side (Frankenstein):**
* `gpg --homedir /root/.gnupg --quick-generate-key "Frankenstein binhost <binhost@gentoo-ryzen.lan>" ed25519 sign never`
* `make.conf`: `FEATURES="… buildpkg binpkg-signing"`, `BINPKG_GPG_SIGNING_KEY="0x88386760B669D0ADBC01D926EB26C91F3ABB14F8"`, `BINPKG_GPG_SIGNING_GPG_HOME="/root/.gnupg"`.
* Sign existing packages with `gpkg-sign`, **one file per call**: `find /var/cache/binpkgs -name '*.gpkg.tar' -print0 | xargs -0 -n 1 -P 12 gpkg-sign --skip-signed` (1,131 packages in 47 s), then `emaint binhost --fix`.
* Export only the public key into the served directory: `gpg --homedir /root/.gnupg --armor --export 0x<fingerprint> > /var/cache/binpkgs/binhost-signing.asc`.
* ⚠️ **Pitfall:** Frankenstein's own Portage verifies signatures too. Until its keyring (`/etc/portage/gnupg`, managed by `getuto`) trusts the key, `emaint binhost --fix` rejects every package and writes an **empty index**. Trust the key (below) on Frankenstein as well, then re-run `emaint binhost --fix`.

**Trusting the key (Battleship, and Frankenstein itself):** run `getuto` if `/etc/portage/gnupg` does not exist, download `binhost-signing.asc`, **check the fingerprint against the table**, then:
```bash
gpg --homedir /etc/portage/gnupg --import binhost-signing.asc
gpg --homedir /etc/portage/gnupg --batch --yes --pinentry-mode loopback \
    --passphrase-file /etc/portage/gnupg/pass --quick-lsign-key 88386760B669D0ADBC01D926EB26C91F3ABB14F8
```
Check: a downloaded package verifies as `Good signature from "Frankenstein binhost" [full]`.

### Pitfalls & settings learned while setting it up
* **Same tree on both machines.** Binaries are used only when the version matches. Update order: Frankenstein syncs and updates first, then the Battleship updates **without syncing again** (for that run use `sudo emerge -vuDN --with-bdeps=y --keep-going @world && sudo emerge --depclean` instead of `up`, whose `eix-sync` would move the tree ahead). A package that is newer in the Battleship's tree (e.g. a new gcc snapshot) compiles locally until Frankenstein has built it.
* **"Ignored due to changed dependencies":** packages packed once with `quickpkg` carry the dependency metadata of their build time. When the tree changes a package's dependencies without a version bump, Portage rejects the old binary. Fix on Frankenstein: `emerge -uDN --changed-deps=y --with-bdeps=y @world` (rebuilt 136 packages the first time).
* **Battleship Portage settings the binhost chroot should mirror:** `package.use/steam` incl. `sys-libs/gdbm abi_x86_32` and `sys-libs/readline abi_x86_32` (needed by 32-bit `pam` via `libcap`, or `@world` does not resolve); `sys-libs/ncurses -gpm` (breaks the 32-bit ncurses ↔ gpm cycle); `app-admin/ryzen_smu dist-kernel`; no `--autounmask-write`/`--autounmask-continue` in `EMERGE_DEFAULT_OPTS` (no silent config rewrites during unattended updates).
* **No `savedconfig` on the Battleship:** the stripped 103-module savedconfig in this repo was made for Frankenstein's hardware; the Battleship runs the full generic module set until it gets its own.
* **Backups inside `/etc/portage`:** Portage reads **every** file in `package.use/` etc., including `foo.bak`. Keep backups elsewhere. The same applies to `/etc/kernel/config.d/`: every file there is merged into the kernel config.
* **CPU flags:** `adx`, `rdseed` and `vaes` no longer exist in `profiles/desc/cpu_flags_x86.desc`, so `cpuid2cpuflags` no longer prints them. Both 5700X and 5800X3D resolve `-march=native` to `znver3`.
* **Kernel config drift:** after each new kernel, compare every line of `/etc/kernel/config.d/*.config` with `/proc/config.gz` (section 1). This is how the dead `CONFIG_MZEN3`, the ineffective `RCU_BOOST` and the non-existent `SENSORS_NCT6687` were found.
* **Checking binhost use** (on Frankenstein):
  ```bash
  sudo awk '{print $1}' /var/log/lighttpd/access.log | sort | uniq -c   # requests per client
  sudo grep -c 'gpkg.tar' /var/log/lighttpd/access.log                    # packages downloaded
  ```
* **Typical update (2026-09-28, 7.2.8):** 474 packages, 391 binaries from Frankenstein, 83 local builds, ~3 h, almost all of it LLVM 22 + 23 built twice (64- and 32-bit). A Frankenstein chroot carrying `package.use/steam` would make the 32-bit stack binary too (optional).
* **DHCP reservation:** reserve `192.168.1.9` for Frankenstein in the router.

### Keeping both machines in step
Binary packages are used only when the version matches. Sync the Gentoo tree on both machines around the same time (`emaint sync -a`) and update Frankenstein first, so its packages are ready when the Battleship updates.
