#!/bin/bash
# fix-missing.sh - Install only what's missing

install_missing_packages() {
    log_info "Installing missing packages..."
    
    local missing_packages=()
    
    # Check main packages
    for pkg in hyprland qbittorrent rofi dunst wireplumber pipewire kate waybar bluez; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log_info "Installing missing: ${missing_packages[*]}"
        sudo pacman -S --noconfirm "${missing_packages[@]}"
    fi
}

fix_services() {
    log_info "Ensuring services are enabled..."
    
    # Enable but don't force start (user might have disabled intentionally)
    sudo systemctl enable bluetooth
    sudo systemctl enable iwd
    
    log_info "You can start services with: systemctl start servicename"
}