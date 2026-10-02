#!/bin/bash
# Install to /usr/local/bin/amdgpu-undervolt.sh (mode 755).
# Sapphire Nitro+ RX 9070 XT (Navi 48 / RDNA 4): undervolt and clock cap.
# RDNA 4 takes offsets from the card's internal maximum (about 3430 MHz here):
# voltage offset -200..0 mV, clock offset -500..+1000 MHz. -500 MHz is the lowest
# allowed and caps boost at about 2930 MHz. Needs amdgpu.ppfeaturemask=0xffffffff.
# Never reuse these numbers on another GPU.

# Wait up to 20 seconds for the GPU driver to initialize.
for i in {1..20}; do
    for card in /sys/class/drm/card*/device/pp_od_clk_voltage; do
        if [ -w "$card" ]; then
            echo "vo -100" > "$card"
            echo "s -500" > "$card"
            echo "c" > "$card"
            # 3D_FULL_SCREEN workload profile: faster clock ramp-up in games
            echo "1" > "${card%/*}/pp_power_profile_mode"
            echo "Applied -100 mV, -500 MHz offset and 3D_FULL_SCREEN profile to $card"
            exit 0
        fi
    done
    sleep 1
done
echo "Timed out waiting for the amdgpu pp_od_clk_voltage node" >&2
exit 1
