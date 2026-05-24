#!/usr/bin/env bash
# install-fonts.sh — Universal font coverage for Arch Linux

set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
GRN='\033[0;32m'
RED='\033[0;31m'
YLW='\033[1;33m'
DIM='\033[2m'
RST='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────────
OK=0
FAIL=0
FAILED=()

# ── Helpers ───────────────────────────────────────────────────────────────────
die() { echo -e "${RED}error:${RST} $*" >&2; exit 1; }

install_pkg() {
    local pkg="$1" src="$2"   # src: "pacman" or "aur"
    printf "  %-48s" "$pkg"
    if [[ "$src" == "pacman" ]]; then
        if pacman -S --noconfirm --needed "$pkg" &>/dev/null; then
            echo -e "${GRN}ok${RST}";  (( OK++  )) || true
        else
            echo -e "${RED}fail${RST}"; (( FAIL++ )) || true
            FAILED+=("$pkg (pacman)")
        fi
    else
        if [[ -z "${AUR_USER:-}" ]]; then
            echo -e "${YLW}skip${RST} (no build user)"; (( FAIL++ )) || true
            FAILED+=("$pkg (aur — no build user)")
        elif ! command -v yay &>/dev/null; then
            echo -e "${YLW}skip${RST} (yay missing)";   (( FAIL++ )) || true
            FAILED+=("$pkg (aur — yay missing)")
        elif sudo -u "$AUR_USER" yay -S --noconfirm --needed "$pkg" &>/dev/null; then
            echo -e "${GRN}ok${RST}";  (( OK++  )) || true
        else
            echo -e "${RED}fail${RST}"; (( FAIL++ )) || true
            FAILED+=("$pkg (aur)")
        fi
    fi
}

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "run as root: sudo bash install-fonts.sh"

AUR_USER=$(awk -F: '$3>=1000 && $3<65534 && $7 !~ /nologin|false/ {print $1; exit}' /etc/passwd || true)

# Allow AUR user to call pacman via sudo without a password for this script.
# The drop-in is removed automatically on exit.
SUDOERS_DROP="/etc/sudoers.d/99-font-install-tmp"
if [[ -n "${AUR_USER:-}" ]]; then
    echo "${AUR_USER} ALL=(ALL) NOPASSWD: /usr/bin/pacman" > "$SUDOERS_DROP"
    chmod 0440 "$SUDOERS_DROP"
    trap 'rm -f "$SUDOERS_DROP"' EXIT
fi

echo
echo -e "  Installing Fonts:  ${DIM}$(date '+%Y-%m-%d %H:%M')${RST}"
echo -e "  ${DIM}──────────────────────────────────────────────────${RST}"
echo

# ── Font list ─────────────────────────────────────────────────────────────────
#  pacman packages
PACMAN_FONTS=(
    # Latin & general purpose
    ttf-dejavu
    ttf-liberation
    ttf-roboto
    ttf-opensans
    ttf-jetbrains-mono
    ttf-ubuntu-font-family
    ttf-hack
    ttf-inconsolata
    ttf-cascadia-code
    gnu-free-fonts
    noto-fonts
    # Unicode safety net
    gnu-unifont
    # CJK
    noto-fonts-cjk
    adobe-source-han-sans-cn-fonts
    adobe-source-han-sans-tw-fonts
    adobe-source-han-sans-jp-fonts
    adobe-source-han-sans-kr-fonts
    adobe-source-han-serif-jp-fonts
    otf-ipafont
    otf-ipaexfont
    ttf-hanazono
    # Arabic, Hebrew & RTL
    noto-fonts-extra
    # Indic & South Asian
    ttf-indic-otf
    # Southeast Asian & Tibetan
    ttf-tibetan-machine
    ttf-khmer
    # Additional Unicode scripts
    ttf-linux-libertine
    ttf-droid
    gsfonts
    adobe-source-code-pro-fonts
    adobe-source-sans-fonts
    adobe-source-serif-fonts
    # Emoji & symbols
    noto-fonts-emoji
    ttf-nerd-fonts-symbols-mono
    ttf-font-awesome
)

#  AUR packages
AUR_FONTS=(
    ttf-amiri
    ttf-ancient-fonts
    ttf-symbola-free
    ttf-quivira
    ttf-gentium-plus
    ttf-jetbrains-mono-nerd
    ttf-firacode-nerd
    ttf-twemoji
)

# ── Install ───────────────────────────────────────────────────────────────────
for pkg in "${PACMAN_FONTS[@]}"; do
    install_pkg "$pkg" "pacman"
done

for pkg in "${AUR_FONTS[@]}"; do
    install_pkg "$pkg" "aur"
done

# ── Fontconfig refresh ────────────────────────────────────────────────────────
echo
printf "  %-48s" "fc-cache"
if fc-cache -fv &>/dev/null; then
    echo -e "${GRN}ok${RST}"
else
    echo -e "${YLW}warn${RST}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$(( OK + FAIL ))
echo
echo -e "  ${DIM}──────────────────────────────────────────────────${RST}"
echo -e "  ${GRN}${OK}${RST}/${TOTAL} installed"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo
    echo -e "  ${YLW}failed:${RST}"
    for entry in "${FAILED[@]}"; do
        echo -e "    ${RED}✘${RST} ${DIM}${entry}${RST}"
    done
    echo
    echo -e "  ${DIM}retry: pacman -S <pkg>  or  yay -S <pkg>${RST}"
fi

echo
echo -e "  ${DIM}tip: fc-match :lang=ja   fc-match :lang=ar   fc-match :lang=hi${RST}"
echo
