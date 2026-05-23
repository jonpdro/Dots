#!/bin/bash
# =============================================================================
#  ARCH LINUX — POST-INSTALL SETUP ORCHESTRATOR
#  Runs each module independently. Failures in one never stop the others.
#  Usage:
#    ./setup.sh              — run all modules
#    ./setup.sh 3 4 7        — run only modules 03, 04, 07
#    ./setup.sh --list       — list available modules
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
RESULTS_FILE="/tmp/arch_setup_results"
export RESULTS_FILE

# ─── Colors (inline, no source needed here) ──────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Module registry ─────────────────────────────────────────────────────────
# Format: "NN|label|filename"
MODULES=(
    "01|System Update          |01_system_update.sh"
    "02|yay (AUR Helper)       |02_yay.sh"
    "03|Network — iwd          |03_iwd.sh"
    "04|Bluetooth + Audio      |04_bluetooth_audio.sh"
    "05|Graphic Drivers        |05_graphic_drivers.sh"
    "06|Core Applications      |06_applications.sh"
    "07|AUR Applications       |07_aur_applications.sh"
    "08|Fonts                  |08_fonts.sh"
)

# ─── Helpers ─────────────────────────────────────────────────────────────────
print_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║         ARCH LINUX — AUTOMATED POST-INSTALL SETUP            ║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

list_modules() {
    echo -e "${BOLD}Available modules:${NC}"
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r num label _ <<< "$entry"
        echo -e "  ${CYAN}$num${NC}  $label"
    done
    echo ""
}

get_module_file() {
    local num="$1"
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r n _ file <<< "$entry"
        if [[ "$n" == "$num" ]]; then
            echo "$MODULES_DIR/$file"
            return 0
        fi
    done
    return 1
}

get_module_label() {
    local num="$1"
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r n label _ <<< "$entry"
        if [[ "$n" == "$num" ]]; then
            echo "$label"
            return 0
        fi
    done
    echo "Module $num"
}

# ─── Guards ──────────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Do not run as root. Use a regular user with sudo rights."
    exit 1
fi

# ─── Argument parsing ────────────────────────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
    list_modules
    exit 0
fi

# Build list of modules to run
SELECTED=()
if [[ $# -eq 0 ]]; then
    # Run all
    for entry in "${MODULES[@]}"; do
        IFS='|' read -r num _ _ <<< "$entry"
        SELECTED+=("$num")
    done
else
    for arg in "$@"; do
        printf -v padded "%02d" "$arg" 2>/dev/null || { echo "Invalid module number: $arg"; exit 1; }
        SELECTED+=("$padded")
    done
fi

# ─── Setup ───────────────────────────────────────────────────────────────────
print_banner

# Reset results log
> "$RESULTS_FILE"

# Temp NOPASSWD sudoers entry (removed in cleanup)
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/arch_setup_tmp &>/dev/null

TOTAL=${#SELECTED[@]}
CURRENT=0
MODULE_RESULTS=()   # "num|label|OK|FAIL" per module

# ─── Progress bar ────────────────────────────────────────────────────────────
print_progress() {
    local current=$1 total=$2 label="$3"
    local filled=$(( current * 40 / total ))
    local empty=$(( 40 - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done
    echo -e "  ${CYAN}[$bar]${NC} $current/$total — ${BOLD}$label${NC}"
}

# ─── Run modules ─────────────────────────────────────────────────────────────
for num in "${SELECTED[@]}"; do
    ((CURRENT++))
    label=$(get_module_label "$num")
    file=$(get_module_file "$num") || {
        echo -e "${RED}[ERROR]${NC} Module $num not found — skipping"
        MODULE_RESULTS+=("$num|$label|0|1")
        continue
    }

    echo ""
    echo -e "${DIM}  ════════════════════════════════════════════════════════════${NC}"
    print_progress "$CURRENT" "$TOTAL" "$label"
    echo -e "${DIM}  ════════════════════════════════════════════════════════════${NC}"

    # Snapshot results count before running module
    before_ok=$(grep "^OK:" "$RESULTS_FILE" 2>/dev/null | wc -l)
    before_fail=$(grep "^FAIL:" "$RESULTS_FILE" 2>/dev/null | wc -l)

    # Run the module in a subshell so failures never kill the orchestrator
    bash "$file" || true

    after_ok=$(grep "^OK:" "$RESULTS_FILE" 2>/dev/null | wc -l)
    after_fail=$(grep "^FAIL:" "$RESULTS_FILE" 2>/dev/null | wc -l)

    mod_ok=$(( after_ok - before_ok ))
    mod_fail=$(( after_fail - before_fail ))
    MODULE_RESULTS+=("$num|$label|$mod_ok|$mod_fail")
done

# ─── Cleanup ─────────────────────────────────────────────────────────────────
sudo rm -f /etc/sudoers.d/arch_setup_tmp

# ─── Final report ────────────────────────────────────────────────────────────
TOTAL_OK=$(grep "^OK:"   "$RESULTS_FILE" 2>/dev/null | wc -l)
TOTAL_FAIL=$(grep "^FAIL:" "$RESULTS_FILE" 2>/dev/null | wc -l)
TOTAL_WARN=$(grep "^WARN:" "$RESULTS_FILE" 2>/dev/null | wc -l)

echo ""
echo -e "${BOLD}${BLUE}  ╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}  ║                     SETUP COMPLETE                           ║${NC}"
echo -e "${BOLD}${BLUE}  ╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Per-module summary
echo -e "${BOLD}  Module results:${NC}"
for entry in "${MODULE_RESULTS[@]}"; do
    IFS='|' read -r num label ok fail <<< "$entry"
    if [[ "$fail" -gt 0 ]]; then
        status="${RED}✗${NC}"
    else
        status="${GREEN}✓${NC}"
    fi
    echo -e "    $status  ${CYAN}$num${NC}  $label  ${DIM}(${ok} ok, ${fail} failed)${NC}"
done

echo ""
echo -e "  ${GREEN}✓ Total succeeded : $TOTAL_OK${NC}"
echo -e "  ${RED}✗ Total failed    : $TOTAL_FAIL${NC}"
echo -e "  ${YELLOW}⚠ Warnings        : $TOTAL_WARN${NC}"

# Failed items detail
if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo ""
    echo -e "${BOLD}${RED}  Failed items:${NC}"
    grep "^FAIL:" "$RESULTS_FILE" | sed 's/^FAIL://' | while read -r item; do
        echo -e "    ${RED}✗${NC} $item"
    done
fi

# Warnings detail
if [[ $TOTAL_WARN -gt 0 ]]; then
    echo ""
    echo -e "${BOLD}${YELLOW}  Warnings:${NC}"
    grep "^WARN:" "$RESULTS_FILE" | sed 's/^WARN://' | while read -r item; do
        echo -e "    ${YELLOW}⚠${NC} $item"
    done
fi

echo ""
echo -e "${DIM}  First boot steps:${NC}"
echo    "    1. Reboot the machine"
echo    "    2. Connect to WiFi  :  iwctl station <dev> connect <SSID>"
echo    "    3. Start Hyprland   :  Hyprland"
echo    "    4. Pair Bluetooth   :  bluetoothctl → power on → scan on → pair <MAC>"
echo ""
echo -e "${DIM}  Config locations  :${NC}"
echo    "    ~/.config/hypr/          ~/.config/waybar/"
echo    "    ~/.config/dunst/         ~/.config/rofi/"
echo    "    ~/.config/nvim/          ~/.config/yazi/"
echo ""
echo -e "${BOLD}${GREEN}  Good luck with the new setup!${NC}"
echo ""
