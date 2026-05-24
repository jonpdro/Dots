#!/bin/bash

# ─────────────────────────────────────────────
#  yay AUR Helper Installer
# ─────────────────────────────────────────────

# ── Colors & symbols ──────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

OK="${GREEN}✔${RESET}"
FAIL="${RED}✘${RESET}"
INFO="${CYAN}➜${RESET}"
WARN="${YELLOW}⚠${RESET}"

# ── Banner ─────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ██╗   ██╗ █████╗ ██╗   ██╗"
echo "  ╚██╗ ██╔╝██╔══██╗╚██╗ ██╔╝"
echo "   ╚████╔╝ ███████║ ╚████╔╝ "
echo "    ╚██╔╝  ██╔══██║  ╚██╔╝  "
echo "     ██║   ██║  ██║   ██║   "
echo "     ╚═╝   ╚═╝  ╚═╝   ╚═╝   "
echo -e "${RESET}"
echo -e "  ${BOLD}AUR Helper Installer${RESET}"
echo -e "  ────────────────────────────────"
echo ""

# ── Helper functions ───────────────────────────
step() { echo -e "\n${INFO} ${BOLD}$1${RESET}"; }
ok()   { echo -e "  ${OK} $1"; }
fail() { echo -e "  ${FAIL} ${RED}$1${RESET}"; }
warn() { echo -e "  ${WARN} ${YELLOW}$1${RESET}"; }

# ── Check: already installed? ──────────────────
step "Checking for existing yay installation..."
if command -v yay &>/dev/null; then
    ok "yay is already installed: $(yay --version | head -n1)"
    echo ""
    echo -e "  ${BOLD}Nothing to do. Exiting.${RESET}"
    echo ""
    exit 1
fi
echo -e "  ${INFO} yay not found — proceeding with installation."

# ── Check: running as root? ────────────────────
step "Checking user context..."
if [[ "$EUID" -eq 0 ]]; then
    fail "This script must NOT be run as root (makepkg requirement)."
    echo -e "     Run as a regular user with sudo privileges."
    exit 1
fi
ok "Running as non-root user: ${USER}"

# ── Check: sudo available? ─────────────────────
step "Checking sudo access..."
if ! sudo -v &>/dev/null; then
    fail "sudo not available or not configured for this user."
    exit 1
fi
ok "sudo access confirmed."

# ── Check: required dependencies ──────────────
step "Checking required dependencies..."

MISSING=()

check_dep() {
    local name="$1"
    local cmd="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        ok "$name is installed"
    else
        fail "$name is NOT installed"
        MISSING+=("$name")
    fi
}

check_dep "git"
check_dep "curl"
check_dep "makepkg"           # part of pacman / base-devel
check_dep "fakeroot"          # part of base-devel
check_dep "gcc"               # part of base-devel
check_dep "make"              # part of base-devel

# Also verify pacman itself
if command -v pacman &>/dev/null; then
    ok "pacman is available"
else
    fail "pacman not found — are you on Arch Linux?"
    exit 1
fi

# ── Install missing deps ───────────────────────
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    warn "Missing dependencies: ${MISSING[*]}"
    echo -e "  ${INFO} Installing via pacman (base-devel + git covers all of these)..."
    echo ""
    if ! sudo pacman -S --needed --noconfirm base-devel git; then
        fail "Failed to install dependencies. Aborting."
        exit 1
    fi
    ok "Dependencies installed."
else
    ok "All dependencies satisfied."
fi

# ── System update ──────────────────────────────
step "Updating system packages..."
if ! sudo pacman -Syu --noconfirm; then
    fail "System update failed. Aborting."
    exit 1
fi
ok "System is up to date."

# ── Build & install yay ────────────────────────
step "Building and installing yay from AUR..."

BUILD_DIR="$(mktemp -d /tmp/yay-build-XXXXXX)"
echo -e "  ${INFO} Build directory: ${BUILD_DIR}"

cleanup() {
    echo ""
    step "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
    ok "Removed ${BUILD_DIR}"

    # Remove any builder users that makepkg may have created
    # (rare, but some setups auto-create a 'builder' user)
    for user in builder makepkg aur; do
        if id "$user" &>/dev/null; then
            warn "Found leftover build user '${user}' — removing..."
            sudo userdel -r "$user" 2>/dev/null && ok "Removed user '${user}'" \
                || warn "Could not remove '${user}' (may need manual cleanup)"
        fi
    done
}

# Run cleanup on exit (success or failure)
trap cleanup EXIT

cd "$BUILD_DIR" || { fail "Cannot enter build directory."; exit 1; }

echo -e "  ${INFO} Fetching PKGBUILD..."
if ! curl -fsSL -o PKGBUILD 'https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=yay'; then
    fail "Failed to download PKGBUILD."
    exit 1
fi
ok "PKGBUILD downloaded."

echo ""
echo -e "  ${INFO} Running makepkg (this may take a moment)..."
echo ""
if ! makepkg -si --noconfirm; then
    fail "makepkg failed. Check the output above for details."
    exit 1
fi

# ── Verify ─────────────────────────────────────
echo ""
step "Verifying installation..."
if command -v yay &>/dev/null; then
    VERSION="$(yay --version | head -n1)"
    ok "yay installed successfully: ${VERSION}"
else
    fail "yay binary not found after installation. Something went wrong."
    exit 1
fi

# ── Done ───────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${GREEN}${BOLD}  🎉  yay is ready to use!${RESET}"
echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  Try: ${CYAN}yay -S <package>${RESET}"
echo ""
