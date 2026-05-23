#!/bin/bash
# =============================================================================
#  MODULE 05 — Graphic Drivers (AMD + Xorg)
# =============================================================================
source "$(dirname "$0")/modules/00_common.sh"

print_module_header "Graphic Drivers — AMD + Xorg"

PACKAGES=(
    mesa
    libva-mesa-driver
    vulkan-radeon
    xf86-video-amdgpu
    xf86-video-ati
    xorg-server
    xorg-xinit
)

for pkg in "${PACKAGES[@]}"; do
    pacman_install "$pkg"
done

# Hardware detection hint
GPU_INFO=$(lspci 2>/dev/null | grep -i "VGA\|3D\|Display" || echo "")
if echo "$GPU_INFO" | grep -qi "AMD\|ATI\|Radeon"; then
    print_ok "AMD/Radeon GPU detected — drivers match your hardware"
elif echo "$GPU_INFO" | grep -qi "VMware\|VirtualBox\|QEMU"; then
    print_warn "VM detected — consider xf86-video-vmware or virtualbox-guest-utils"
elif [[ -n "$GPU_INFO" ]]; then
    print_warn "Non-AMD GPU detected — AMD drivers may not be optimal"
    print_warn "$(echo "$GPU_INFO" | head -1)"
fi

print_done
