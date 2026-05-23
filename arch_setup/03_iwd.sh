#!/bin/bash
# =============================================================================
#  MODULE 03 — Network (iwd)
# =============================================================================
source "$(dirname "$0")/modules/00_common.sh"

print_module_header "Network — iwd"

# Disable conflicting services
for svc in NetworkManager wpa_supplicant; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        sudo systemctl stop    "$svc" &>/dev/null && print_warn "$svc was running — stopped"
        sudo systemctl disable "$svc" &>/dev/null
    fi
done

pacman_install "iwd"

print_info "Writing /etc/iwd/main.conf ..."
sudo mkdir -p /etc/iwd
sudo tee /etc/iwd/main.conf &>/dev/null <<'EOF'
[General]
EnableNetworkConfiguration=true
UseDefaultInterface=true

[Network]
NameResolvingService=systemd
EOF
print_ok "/etc/iwd/main.conf written"

run "Enable iwd service" sudo systemctl enable iwd
run "Start  iwd service" sudo systemctl start  iwd

# Detect wireless interfaces
IFACES=$(ip link show 2>/dev/null | grep -o "wl[^:]*" || true)
if [[ -n "$IFACES" ]]; then
    print_info "Wireless interfaces found: $IFACES"
else
    print_warn "No wireless interfaces detected"
fi

print_done
