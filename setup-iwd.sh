#!/usr/bin/env bash
# setup-iwd.sh — Sets up iwd as the sole wireless manager on Arch Linux
# Disables NetworkManager, dhcpcd, and systemd-networkd if active.

set -euo pipefail

# ── Helpers ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }

# ── Root check ─────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || error "Run this script as root: sudo bash setup-iwd.sh"

# ── 1. Check iwd is installed ──────────────────────────────────────────────────
info "Checking for iwd..."
if ! command -v iwctl &>/dev/null; then
    warn "iwd not found. Installing..."
    pacman -Sy --noconfirm iwd || error "Failed to install iwd."
fi
success "iwd is installed."

# ── 2. Disable conflicting services ───────────────────────────────────────────
CONFLICTS=(NetworkManager dhcpcd systemd-networkd)

for svc in "${CONFLICTS[@]}"; do
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        info "Disabling $svc..."
        systemctl disable --now "$svc" 2>/dev/null || warn "Could not disable $svc (may not be installed)."
    else
        warn "$svc is already disabled or not installed — skipping."
    fi
done

# ── 3. Write iwd config ────────────────────────────────────────────────────────
IWD_CONF="/etc/iwd/main.conf"
info "Writing $IWD_CONF..."
mkdir -p /etc/iwd

cat > "$IWD_CONF" <<'EOF'
[General]
EnableNetworkConfiguration=true

[Network]
EnableIPv6=true
NameResolvingService=systemd
EOF

success "iwd config written."

# ── 4. Enable systemd-resolved ─────────────────────────────────────────────────
info "Enabling systemd-resolved..."
systemctl enable --now systemd-resolved || error "Failed to enable systemd-resolved."
success "systemd-resolved is active."

# ── 5. Enable and start iwd ────────────────────────────────────────────────────
info "Enabling and starting iwd..."
systemctl enable --now iwd || error "Failed to start iwd."

# Give iwd a moment to initialize
sleep 1

if systemctl is-active --quiet iwd; then
    success "iwd is running."
else
    error "iwd failed to start. Run: journalctl -u iwd -n 30 --no-pager"
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  iwd setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  To connect to a network, run:"
echo "    iwctl"
echo "    > station wlan0 scan"
echo "    > station wlan0 get-networks"
echo "    > station wlan0 connect \"YourSSID\""
echo ""
echo "  To verify connectivity after connecting:"
echo "    ping -c 3 archlinux.org"
echo ""
