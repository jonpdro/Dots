#!/usr/bin/env bash
# =============================================================================
#  post-install.sh — Post-archinstall chroot setup
#  Beelink SER5 Max (AMD Ryzen 5xxx / Radeon Vega)
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Icons ─────────────────────────────────────────────────────────────────────
ARROW="➜"
CHECK="✔"
CROSS="✘"
GEAR="⚙"
STAR="★"
BOLT="⚡"
MUSIC="♪"
WIFI="⦾"
BT="⦿"
PKG="◈"

# ── Helpers ───────────────────────────────────────────────────────────────────
header() {
    echo
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  $1${RESET}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════${RESET}"
    echo
}

step() {
    echo -e "  ${CYAN}${ARROW}${RESET} ${BOLD}$1${RESET}"
}

ok() {
    echo -e "  ${GREEN}${CHECK}${RESET} ${DIM}$1${RESET}"
}

warn() {
    echo -e "  ${YELLOW}⚠ $1${RESET}"
}

die() {
    echo -e "\n  ${RED}${CROSS} ERROR: $1${RESET}\n"
    exit 1
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo
        echo -e "  ${YELLOW}⚠  This script must run as root (e.g. inside chroot as root).${RESET}"
        echo -e "  ${DIM}Re-run with: sudo bash post-install.sh${RESET}"
        echo
        exit 1
    fi
}

# ── Sanity check ──────────────────────────────────────────────────────────────
require_root

clear
echo
echo -e "${BOLD}${CYAN}"
echo "    ╔═══════════════════════════════════════════╗"
echo "    ║     Arch Linux — Post-Install Setup       ║"
echo "    ║       Beelink SER5 Max  •  AMD Ryzen      ║"
echo "    ╚═══════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  ${DIM}Running as: $(whoami)   •   $(date '+%Y-%m-%d %H:%M')${RESET}"

# =============================================================================
#  1. SYSTEM UPDATE
# =============================================================================
header "${GEAR}  System Update"

step "Syncing package databases and upgrading system..."
pacman -Syu --noconfirm
ok "System is up to date."

# =============================================================================
#  2. BASE PACKAGES
# =============================================================================
header "${PKG}  Base Packages"

PKGS=(git base-devel)
for pkg in "${PKGS[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
        ok "$pkg is already installed — skipping."
    else
        step "Installing $pkg..."
        pacman -S --noconfirm "$pkg"
        ok "$pkg installed."
    fi
done

# =============================================================================
#  3. YAY (AUR helper)
# =============================================================================
header "${STAR}  AUR Helper — yay"

if command -v yay &>/dev/null; then
    ok "yay is already installed — skipping."
else
    step "Detecting a non-root user to build yay..."

    BUILD_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 && $7 !~ /nologin|false/ {print $1; exit}' /etc/passwd)

    if [[ -z "$BUILD_USER" ]]; then
        warn "No non-root user found. Creating a temporary build user..."
        useradd -m -G wheel _builduser
        BUILD_USER="_builduser"
        TEMP_USER=true
    else
        TEMP_USER=false
        ok "Using build user: ${BUILD_USER}"
    fi

    BUILD_HOME=$(eval echo "~${BUILD_USER}")

    step "Cloning yay into ${BUILD_HOME}/yay..."
    sudo -u "$BUILD_USER" git clone https://aur.archlinux.org/yay.git "${BUILD_HOME}/yay"

    step "Building and installing yay (makepkg)..."
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-yay-build
    sudo -u "$BUILD_USER" bash -c "cd ${BUILD_HOME}/yay && makepkg -si --noconfirm"
    rm -f /etc/sudoers.d/99-yay-build

    step "Cleaning up build artifacts..."
    rm -rf "${BUILD_HOME}/yay"
    ok "Build directory removed."

    if [[ "$TEMP_USER" == true ]]; then
        userdel -r _builduser 2>/dev/null || true
        ok "Temporary build user removed."
    fi

    ok "yay installed successfully."
fi

# Clean up any leftover build users from archinstall or previous runs
step "Removing any leftover build users (builder, _builduser)..."
for leftover in builder _builduser; do
    if id "$leftover" &>/dev/null; then
        userdel -r "$leftover" 2>/dev/null || true
        ok "Removed leftover user: ${leftover}"
    fi
done

# =============================================================================
#  4. NETWORK — iwd
# =============================================================================
header "${WIFI}  Network — iwd"

step "Installing iwd..."
pacman -S --noconfirm iwd
ok "iwd installed."

step "Masking conflicting network services (dhcpcd, NetworkManager, wpa_supplicant)..."
for svc in dhcpcd NetworkManager wpa_supplicant; do
    if systemctl list-unit-files "${svc}.service" &>/dev/null; then
        systemctl disable --now "$svc" 2>/dev/null || true
        systemctl mask "$svc" 2>/dev/null || true
        ok "${svc} masked."
    fi
done

step "Enabling and starting iwd..."
systemctl enable --now iwd
ok "iwd enabled and running."

# =============================================================================
#  5. BLUETOOTH
# =============================================================================
header "${BT}  Bluetooth"

step "Installing bluez and bluez-utils..."
pacman -S --noconfirm bluez bluez-utils
ok "bluez packages installed."

step "Enabling bluetooth service..."
systemctl enable --now bluetooth
ok "Bluetooth enabled and running."

# =============================================================================
#  6. AUDIO — PipeWire
# =============================================================================
header "${MUSIC}  Audio — PipeWire"

AUDIO_PKGS=(
    pipewire
    pipewire-alsa
    pipewire-pulse
    pipewire-jack
    wireplumber
)

step "Installing PipeWire stack..."
pacman -S --noconfirm "${AUDIO_PKGS[@]}"
ok "PipeWire stack installed."

step "Enabling PipeWire as a user-session service for all human users..."
while IFS=: read -r username _ uid _ _ homedir shell; do
    [[ "$uid" -lt 1000 || "$uid" -ge 65534 ]] && continue
    [[ "$shell" =~ (nologin|false) ]] && continue
    sudo -u "$username" XDG_RUNTIME_DIR="/run/user/${uid}" \
        systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null && \
        ok "PipeWire enabled for user: ${username}" || \
        warn "Could not enable PipeWire for ${username} — enable manually after first login."
done < /etc/passwd

# =============================================================================
#  7. AMD DRIVERS — Beelink SER5 Max (Ryzen 5xxx / Radeon Vega / RDNA2)
# =============================================================================
header "${BOLT}  AMD Drivers"

AMD_PKGS=(
    mesa                        # OpenGL / Vulkan (radeonsi) — VDPAU bundled since Mesa 24
    lib32-mesa                  # 32-bit OpenGL (Steam / Wine)
    vulkan-radeon               # Vulkan (RADV — community driver)
    lib32-vulkan-radeon         # 32-bit Vulkan
    libva-mesa-driver           # VA-API (hardware video decode)
    lib32-libva-mesa-driver     # 32-bit VA-API
    xf86-video-amdgpu           # Xorg DDX driver
)

step "Enabling multilib repository (required for lib32 packages)..."
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    ok "multilib enabled in pacman.conf."
else
    ok "multilib already enabled."
fi

step "Refreshing package databases after multilib change..."
pacman -Sy --noconfirm

step "Installing AMD GPU drivers, VA-API and VDPAU stack..."
pacman -S --noconfirm "${AMD_PKGS[@]}"
ok "AMD drivers installed."

step "Adding amdgpu to early KMS modules in mkinitcpio.conf..."
if ! grep -q 'amdgpu' /etc/mkinitcpio.conf; then
    sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 amdgpu)/' /etc/mkinitcpio.conf
    sed -i 's/MODULES=(  /MODULES=(/' /etc/mkinitcpio.conf
    ok "amdgpu added to MODULES."
else
    ok "amdgpu already present in MODULES — skipping."
fi

step "Rebuilding initramfs..."
mkinitcpio -P
ok "Initramfs rebuilt."

# =============================================================================
#  DONE
# =============================================================================
echo
echo -e "${BOLD}${GREEN}"
echo "    ╔═══════════════════════════════════════════╗"
echo "    ║           Setup complete! ✔               ║"
echo "    ╚═══════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  ${DIM}Summary of what was done:${RESET}"
echo -e "  ${GREEN}${CHECK}${RESET} System updated"
echo -e "  ${GREEN}${CHECK}${RESET} git + base-devel installed"
echo -e "  ${GREEN}${CHECK}${RESET} yay (AUR helper) installed"
echo -e "  ${GREEN}${CHECK}${RESET} iwd installed & enabled  (network)"
echo -e "  ${GREEN}${CHECK}${RESET} bluez installed & enabled (bluetooth)"
echo -e "  ${GREEN}${CHECK}${RESET} PipeWire stack installed  (audio)"
echo -e "  ${GREEN}${CHECK}${RESET} AMD GPU drivers + VA-API installed"
echo -e "  ${GREEN}${CHECK}${RESET} Early KMS set + initramfs rebuilt"
echo
echo -e "  ${YELLOW}Next steps after reboot:${RESET}"
echo -e "  ${DIM}• Connect to Wi-Fi :  iwctl${RESET}"
echo -e "  ${DIM}• Pair Bluetooth   :  bluetoothctl${RESET}"
echo -e "  ${DIM}• Check audio      :  wpctl status${RESET}"
echo
