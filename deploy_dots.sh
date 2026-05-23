#!/bin/bash
# =============================================================================
#  DOTFILES DEPLOY
#  Copies config folders from the repo to ~/.config/
#  Run from the root of your Dots repo.
#  Usage: ./deploy_dots.sh
# =============================================================================

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_info() { echo -e "${BLUE}│  ·${NC} $1"; }
print_ok()   { echo -e "${GREEN}│  ✓${NC} $1"; }
print_warn() { echo -e "${YELLOW}│  ⚠${NC} $1"; }
print_fail() { echo -e "${RED}│  ✗${NC} $1"; }
print_done() { echo -e "${CYAN}└──${NC} ${GREEN}Done.${NC}"; }

SUCCEEDED=()
FAILED=()

# ─── Folders to skip (not config dirs) ───────────────────────────────────────
SKIP=("arch_setup" ".git")

# ─── Header ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║               DOTFILES DEPLOYMENT SCRIPT                    ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}│${NC}  Source : $(pwd)"
echo -e "${BLUE}│${NC}  Target : $HOME/.config/"
echo ""

mkdir -p "$HOME/.config"

# ─── Deploy ──────────────────────────────────────────────────────────────────
for dir in */; do
    name="${dir%/}"

    # Skip non-config folders
    for skip in "${SKIP[@]}"; do
        [[ "$name" == "$skip" ]] && continue 2
    done

    src="$(pwd)/$name"
    dest="$HOME/.config/$name"

    print_info "Deploying $name → ~/.config/$name"

    if cp -rf "$src" "$HOME/.config/"; then
        print_ok "$name"
        SUCCEEDED+=("$name")
    else
        print_fail "$name"
        FAILED+=("$name")
    fi
done

print_done

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║                       COMPLETE                              ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓ Deployed : ${#SUCCEEDED[@]}${NC}  — ${SUCCEEDED[*]}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "  ${RED}✗ Failed   : ${#FAILED[@]}${NC}  — ${FAILED[*]}"
fi

echo ""
