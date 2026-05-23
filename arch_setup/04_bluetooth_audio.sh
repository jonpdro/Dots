#!/bin/bash
# =============================================================================
#  MODULE 04 — Bluetooth + Audio (Pipewire)
# =============================================================================
source "$(dirname "$0")/modules/00_common.sh"

print_module_header "Bluetooth + Audio (Pipewire)"

PACKAGES=(
    bluez
    bluez-utils
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber
)

for pkg in "${PACKAGES[@]}"; do
    pacman_install "$pkg"
done

print_info "Writing /etc/bluetooth/main.conf ..."
sudo mkdir -p /etc/bluetooth
sudo tee /etc/bluetooth/main.conf &>/dev/null <<'EOF'
[General]
AutoEnable=true
Name = Arch Bluetooth
Class = 0x20041C
Experimental = true
KernelExperimental = true
ControllerMode = dual
JustWorksRepairing = always
Privacy = device
EOF
print_ok "/etc/bluetooth/main.conf written"

run "Enable bluetooth service" sudo systemctl enable bluetooth.service

print_info "Loading BT kernel modules..."
sudo modprobe btusb     2>/dev/null || true
sudo modprobe bluetooth 2>/dev/null || true
sudo mkdir -p /etc/modules-load.d
echo -e "btusb\nbluetooth" | sudo tee /etc/modules-load.d/bluetooth.conf &>/dev/null
print_ok "Kernel modules configured for autoload"

print_info "Enabling Pipewire user services (effective after first login)..."
systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null \
    && { print_ok "Pipewire user services enabled"; log_ok "pipewire user services"; } \
    || print_warn "Could not enable user services now — will activate on first login"

print_done
