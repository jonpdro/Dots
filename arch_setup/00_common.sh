#!/bin/bash
# =============================================================================
#  COMMON — Colors, helpers, and tracking arrays
#  Source this file at the top of every module.
# =============================================================================

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Shared result log (file-based so it persists across sourced scripts) ────
RESULTS_FILE="${RESULTS_FILE:-/tmp/arch_setup_results}"

log_ok()   { echo "OK:$1"   >> "$RESULTS_FILE"; }
log_fail() { echo "FAIL:$1" >> "$RESULTS_FILE"; }
log_warn() { echo "WARN:$1" >> "$RESULTS_FILE"; }

# ─── Print helpers ───────────────────────────────────────────────────────────
print_info() { echo -e "${BLUE}│  ·${NC} $1"; }
print_ok()   { echo -e "${GREEN}│  ✓${NC} $1"; }
print_warn() { echo -e "${YELLOW}│  ⚠${NC} $1"; log_warn "$1"; }
print_fail() { echo -e "${RED}│  ✗${NC} $1"; }
print_done() { echo -e "${CYAN}└──${NC} ${GREEN}Done.${NC}"; }

print_module_header() {
    echo ""
    echo -e "${BOLD}${CYAN}┌─── $1 ───${NC}"
}

# ─── Run wrapper ─────────────────────────────────────────────────────────────
run() {
    local label="$1"; shift
    if "$@" &>/dev/null; then
        print_ok "$label"
        log_ok "$label"
        return 0
    else
        print_fail "$label"
        log_fail "$label"
        return 1
    fi
}

# ─── Package installers ──────────────────────────────────────────────────────
pacman_install() {
    local pkg="$1"
    if sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
        print_ok "$pkg"
        log_ok "pacman: $pkg"
    else
        print_fail "$pkg"
        log_fail "pacman: $pkg"
    fi
}

yay_install() {
    local pkg="$1"
    if ! command -v yay &>/dev/null; then
        print_warn "yay not found — skipping $pkg"
        return
    fi
    if yay -S --needed --noconfirm "$pkg" &>/dev/null; then
        print_ok "$pkg"
        log_ok "aur: $pkg"
    else
        print_fail "$pkg"
        log_fail "aur: $pkg"
    fi
}
