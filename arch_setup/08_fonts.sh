#!/bin/bash
# =============================================================================
#  MODULE 08 — Fonts
# =============================================================================
source "$(dirname "$0")/modules/00_common.sh"

print_module_header "Fonts"

# ─── Official repos ───────────────────────────────────────────────────────────
OFFICIAL_FONTS=(
    adobe-source-code-pro-fonts
    adobe-source-sans-fonts
    adobe-source-serif-fonts
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    noto-fonts-extra
    ttf-ubuntu-font-family
    ttf-dejavu
    ttf-liberation
    ttf-hack
    ttf-inconsolata
    ttf-cascadia-code
    ttf-font-awesome
    gsfonts
    gnu-free-fonts
    otf-ipafont
    adobe-source-han-sans-jp-fonts
    adobe-source-han-serif-jp-fonts
)

print_info "Installing fonts from official repos..."
for font in "${OFFICIAL_FONTS[@]}"; do
    pacman_install "$font"
done

# ─── AUR fonts ────────────────────────────────────────────────────────────────
if ! command -v yay &>/dev/null; then
    print_warn "yay not available — skipping AUR fonts"
else
    AUR_FONTS=(
        ttf-nerd-fonts-symbols
        ttf-nerd-fonts-symbols-common
        ttf-jetbrains-mono-nerd
        ttf-firacode-nerd
        ttf-ms-fonts
        ttf-twemoji
    )

    print_info "Installing fonts from AUR..."
    for font in "${AUR_FONTS[@]}"; do
        yay_install "$font"
    done
fi

# ─── Rebuild font cache ───────────────────────────────────────────────────────
run "Font cache rebuilt" fc-cache -fv

FONT_COUNT=$(fc-list 2>/dev/null | wc -l)
FONT_FAMILIES=$(fc-list : family 2>/dev/null | sort -u | wc -l)
print_info "Total font faces: $FONT_COUNT across $FONT_FAMILIES families"

print_done
