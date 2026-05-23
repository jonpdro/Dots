#!/usr/bin/env bash
# =============================================================================
#  install-fonts.sh — Universal font coverage setup
#  Covers Latin, CJK, Arabic, Hebrew, Indic, symbols, emoji, and more
# =============================================================================

# No set -e: errors are handled per-package and reported at the end
set -uo pipefail

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
FONT="◉"
GEAR="⚙"
STAR="★"

# ── Counters & failure tracker ────────────────────────────────────────────────
PACMAN_OK=0
PACMAN_TOTAL=0
AUR_OK=0
AUR_TOTAL=0
FAILED=()

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

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo
        echo -e "  ${YELLOW}⚠  This script must run as root.${RESET}"
        echo -e "  ${DIM}Re-run with: sudo bash install-fonts.sh${RESET}"
        echo
        exit 1
    fi
}

# install_pacman <friendly-label> <pkg> [pkg ...]
#   Installs packages one-by-one via pacman so a single bad package
#   never blocks the rest. Tracks counters and failures.
install_pacman() {
    local label="$1"; shift
    local pkgs=("$@")
    local total=${#pkgs[@]}
    local idx=0

    step "Installing ${label} (${total} package(s))..."
    for pkg in "${pkgs[@]}"; do
        (( idx++ )) || true
        (( PACMAN_TOTAL++ )) || true
        printf "    ${DIM}[%d/%d]${RESET} %-45s" "$idx" "$total" "$pkg"
        if pacman -S --noconfirm --needed "$pkg" &>/dev/null; then
            echo -e "${GREEN}${CHECK}${RESET}"
            (( PACMAN_OK++ )) || true
        else
            echo -e "${RED}${CROSS}${RESET}"
            FAILED+=("${pkg}  ${DIM}(pacman)${RESET}")
        fi
    done
    ok "${label}: ${idx} attempted."
}

# install_aur <pkg> <friendly-label>
#   Installs a single AUR package via yay as the detected non-root user.
install_aur() {
    local pkg="$1"
    local label="$2"
    (( AUR_TOTAL++ )) || true

    step "Installing ${label} from AUR..."
    if [[ -z "${AUR_USER:-}" ]]; then
        warn "Skipped — no non-root user available.  yay -S ${pkg}"
        FAILED+=("${pkg}  ${DIM}(AUR — no build user)${RESET}")
        return
    fi
    if ! command -v yay &>/dev/null; then
        warn "Skipped — yay not found.  Install manually: yay -S ${pkg}"
        FAILED+=("${pkg}  ${DIM}(AUR — yay missing)${RESET}")
        return
    fi
    if sudo -u "$AUR_USER" yay -S --noconfirm --needed "$pkg"; then
        ok "${label} installed from AUR."
        (( AUR_OK++ )) || true
    else
        warn "${label} — AUR build failed. Recording for summary."
        FAILED+=("${pkg}  ${DIM}(AUR)${RESET}")
    fi
}

# ── Sanity checks ─────────────────────────────────────────────────────────────
require_root

AUR_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 && $7 !~ /nologin|false/ \
    {print $1; exit}' /etc/passwd || true)

clear
echo
echo -e "${BOLD}${CYAN}"
echo "    ╔═══════════════════════════════════════════╗"
echo "    ║       Universal Font Coverage Setup       ║"
echo "    ║         Arch Linux  •  All Scripts        ║"
echo "    ╚═══════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  ${DIM}Running as: $(whoami)   •   $(date '+%Y-%m-%d %H:%M')${RESET}"

# =============================================================================
#  1. LATIN & GENERAL PURPOSE
#     High-quality, widely compatible fonts for everyday UI and documents
# =============================================================================
header "${FONT}  Latin & General Purpose"

install_pacman "Latin & general purpose" \
    ttf-dejavu                  \
    ttf-liberation              \
    ttf-roboto                  \
    ttf-opensans                \
    ttf-jetbrains-mono          \
    ttf-ubuntu-font-family      \
    ttf-hack                    \
    ttf-inconsolata             \
    ttf-cascadia-code           \
    gnu-free-fonts              \
    noto-fonts

# =============================================================================
#  2. UNICODE SAFETY NET
#     gnu-unifont covers ~70k glyphs — the ultimate "no blank box" fallback
# =============================================================================
header "${FONT}  Unicode Safety Net"

install_pacman "Unicode safety net" \
    gnu-unifont

# =============================================================================
#  3. CJK — Chinese, Japanese, Korean
#     Sans + Serif, official + IPA quality
# =============================================================================
header "${FONT}  CJK — Chinese · Japanese · Korean"

install_pacman "CJK fonts" \
    noto-fonts-cjk                      \
    adobe-source-han-sans-cn-fonts      \
    adobe-source-han-sans-tw-fonts      \
    adobe-source-han-sans-jp-fonts      \
    adobe-source-han-sans-kr-fonts      \
    adobe-source-han-serif-jp-fonts     \
    otf-ipafont                         \
    otf-ipaexfont                       \
    ttf-hanazono

# =============================================================================
#  4. ARABIC, HEBREW & RTL SCRIPTS
# =============================================================================
header "${FONT}  Arabic · Hebrew · RTL Scripts"

install_pacman "RTL base fonts" \
    noto-fonts-extra

install_aur "ttf-amiri" "Amiri (classical Arabic)"

# =============================================================================
#  5. INDIC & SOUTH ASIAN SCRIPTS
#     Devanagari, Bengali, Tamil, Telugu, Kannada, Malayalam, Gujarati, etc.
# =============================================================================
header "${FONT}  Indic & South Asian Scripts"

install_pacman "Indic & South Asian fonts" \
    ttf-indic-otf

# =============================================================================
#  6. SOUTHEAST ASIAN & TIBETAN SCRIPTS
# =============================================================================
header "${FONT}  Southeast Asian & Tibetan Scripts"

install_pacman "Southeast Asian & Tibetan fonts" \
    ttf-tibetan-machine     \
    ttf-khmer

# =============================================================================
#  7. ADDITIONAL UNICODE SCRIPTS
#     Greek, Cyrillic, Georgian, Armenian, and broad legacy coverage
# =============================================================================
header "${FONT}  Additional Unicode Scripts"

install_pacman "Additional Unicode fonts" \
    ttf-linux-libertine     \
    ttf-droid               \
    gsfonts                 \
    adobe-source-code-pro-fonts     \
    adobe-source-sans-fonts         \
    adobe-source-serif-fonts

# =============================================================================
#  8. EMOJI & SYMBOLS
# =============================================================================
header "${STAR}  Emoji & Symbols"

install_pacman "Emoji & symbol fonts" \
    noto-fonts-emoji                \
    ttf-nerd-fonts-symbols-mono     \
    ttf-font-awesome

# =============================================================================
#  9. AUR — EXTENDED COVERAGE & ANCIENT SCRIPTS
# =============================================================================
header "${FONT}  AUR — Extended & Ancient Scripts"

install_aur "ttf-ancient-fonts"   "Ancient scripts (Runic, Ogham, Linear B, Cuneiform…)"
install_aur "ttf-symbola-free"    "Symbola (broad symbol & misc Unicode coverage)"
install_aur "ttf-quivira"         "Quivira (Medieval, Byzantine, rare Unicode)"
install_aur "ttf-gentium-plus"    "Gentium Plus (broad Latin, Greek, Cyrillic)"

# =============================================================================
#  10. AUR — NERD FONTS & POWERLINE
# =============================================================================
header "${STAR}  AUR — Nerd Fonts & Powerline"

install_aur "ttf-jetbrains-mono-nerd" "JetBrains Mono Nerd (full icon patched)"
install_aur "ttf-firacode-nerd"       "FiraCode Nerd (ligatures + icons)"
install_aur "ttf-twemoji"             "Twemoji (Twitter emoji, broad coverage)"

# =============================================================================
#  11. FONTCONFIG — SYSTEM REFRESH & VERIFICATION
# =============================================================================
header "${GEAR}  Fontconfig Cache & Verification"

step "Rebuilding fontconfig cache..."
fc-cache -fv 2>&1 | grep -E '^\/' | sed 's/^/    /'
ok "Font cache rebuilt."

echo
step "Running coverage checks..."

check_lang() {
    local lang="$1" label="$2"
    if fc-list | grep -qi "$lang"; then
        ok "${label} fonts detected."
    else
        warn "${label} fonts NOT detected — check manually: fc-list | grep -i '${lang}'"
    fi
}

check_lang "noto.*cjk"   "Noto CJK"
check_lang "noto.*emoji" "Noto Emoji"
check_lang "unifont"     "GNU Unifont"
check_lang "amiri"       "Amiri (Arabic)"
check_lang "ipafont\|ipaex" "IPA (Japanese)"

echo
step "Font statistics..."
FONT_COUNT=$(fc-list | wc -l)
FONT_FAMILIES=$(fc-list : family | sort -u | wc -l)
echo -e "    ${DIM}Total font faces  : ${RESET}${BOLD}${FONT_COUNT}${RESET}"
echo -e "    ${DIM}Total font families: ${RESET}${BOLD}${FONT_FAMILIES}${RESET}"

# =============================================================================
#  DONE
# =============================================================================
echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}"
    echo "    ╔═══════════════════════════════════════════╗"
    echo "    ║         Font setup complete! ✔            ║"
    echo "    ╚═══════════════════════════════════════════╝"
    echo -e "${RESET}"
else
    echo -e "${BOLD}${YELLOW}"
    echo "    ╔═══════════════════════════════════════════╗"
    echo "    ║      Font setup done (with warnings) ⚠   ║"
    echo "    ╚═══════════════════════════════════════════╝"
    echo -e "${RESET}"
fi

echo -e "  ${DIM}Coverage installed:${RESET}"
echo -e "  ${GREEN}${CHECK}${RESET} Latin, Greek, Cyrillic, general UI & mono fonts"
echo -e "  ${GREEN}${CHECK}${RESET} GNU Unifont — ~70k glyph Unicode safety net"
echo -e "  ${GREEN}${CHECK}${RESET} CJK — Chinese (Simplified + Traditional), Japanese (Sans + Serif + IPA), Korean"
echo -e "  ${GREEN}${CHECK}${RESET} Arabic, Hebrew, and other RTL scripts"
echo -e "  ${GREEN}${CHECK}${RESET} Indic scripts (Devanagari, Tamil, Bengali, Telugu…)"
echo -e "  ${GREEN}${CHECK}${RESET} Southeast Asian scripts (Khmer, Tibetan)"
echo -e "  ${GREEN}${CHECK}${RESET} Full color emoji (Noto + Twemoji)"
echo -e "  ${GREEN}${CHECK}${RESET} Symbols, Nerd Fonts, Font Awesome, Powerline"
echo -e "  ${GREEN}${CHECK}${RESET} Ancient & rare Unicode scripts"
echo -e "  ${GREEN}${CHECK}${RESET} Fontconfig cache refreshed"
echo
echo -e "  ${DIM}Pacman packages : ${PACMAN_OK}/${PACMAN_TOTAL} installed${RESET}"
echo -e "  ${DIM}AUR packages    : ${AUR_OK}/${AUR_TOTAL} installed${RESET}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo
    echo -e "  ${YELLOW}The following packages failed to install:${RESET}"
    for entry in "${FAILED[@]}"; do
        echo -e "  ${RED}${CROSS}${RESET} ${entry}"
    done
    echo
    echo -e "  ${DIM}Retry with:  pacman -S <pkg>  or  yay -S <pkg>${RESET}"
fi

echo
echo -e "  ${YELLOW}Tip:${RESET} ${DIM}Use 'fc-match :lang=<code>' to verify fallback chains.${RESET}"
echo -e "  ${DIM}Examples:  fc-match :lang=ja   fc-match :lang=ar   fc-match :lang=hi${RESET}"
echo -e "  ${DIM}To restart apps and apply new fonts, log out and back in.${RESET}"
echo
