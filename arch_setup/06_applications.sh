#!/bin/bash
# =============================================================================
#  MODULE 06 — Core Applications (official repos)
# =============================================================================
source "$(dirname "$0")/modules/00_common.sh"

print_module_header "Core Applications — Official Repos"

PACKAGES=(
    # Hyprland ecosystem
    hyprland
    hyprpaper
    hyprlock
    hypridle
    # UI / shell
    dunst
    rofi
    waybar
    # Editors
    neovim
    kate
    # File management
    yazi
    # Media
    mpv
    # Internet
    chromium
    qbittorrent
)

for pkg in "${PACKAGES[@]}"; do
    pacman_install "$pkg"
done

print_done
