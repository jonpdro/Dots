#!/bin/bash
# =============================================================================
#  MODULE 02 — yay (AUR Helper)
# =============================================================================
source "$(dirname "$0")/modules/00_common.sh"

print_module_header "yay — AUR Helper"

if command -v yay &>/dev/null; then
    print_warn "yay is already installed — skipping"
    print_done
    exit 0
fi

run "Install base-devel and git" sudo pacman -S --needed --noconfirm base-devel git

print_info "Cloning yay from AUR..."
TMP_YAY=$(mktemp -d)

if git clone https://aur.archlinux.org/yay.git "$TMP_YAY/yay" &>/dev/null; then
    print_ok "yay repository cloned"
    cd "$TMP_YAY/yay"
    if makepkg -si --noconfirm &>/dev/null; then
        print_ok "yay built and installed"
        log_ok "yay"
    else
        print_fail "yay build failed"
        log_fail "yay — AUR packages in later modules will be skipped"
    fi
    cd - &>/dev/null
else
    print_fail "Failed to clone yay repository"
    log_fail "yay — AUR packages in later modules will be skipped"
fi

rm -rf "$TMP_YAY"
print_done
