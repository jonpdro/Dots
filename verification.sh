#!/bin/bash
# verify-setup.sh - Check if everything is working

set -e

# Colors (same as before)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_packages() {
    log_info "Checking installed packages..."
    
    local packages=(
        "hyprland" "qbittorrent" "rofi" "dunst" "wireplumber"
        "pipewire" "kate" "waybar" "bluez" "iwd"
        "git" "base-devel" "yay"
    )
    
    local aur_packages=(
        "pywal16" "yazi" "hyprlock" "hypridle" "hyprpaper"
        "mpv" "neovim" "qimgv" "impala" "wiremix"
    )
    
    for pkg in "${packages[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            log_success "$pkg is installed"
        else
            log_error "$pkg is MISSING"
        fi
    done
    
    for pkg in "${aur_packages[@]}"; do
        if yay -Q "$pkg" &>/dev/null 2>/dev/null || pacman -Q "$pkg" &>/dev/null; then
            log_success "$pkg is installed"
        else
            log_error "$pkg is MISSING"
        fi
    done
}

check_services() {
    log_info "Checking services..."
    
    # System services
    local system_services=("bluetooth" "iwd")
    for service in "${system_services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_success "$service is running"
        else
            log_warning "$service is not running"
        fi
    done
    
    # User services
    local user_services=("pipewire" "wireplumber" "pipewire-pulse")
    for service in "${user_services[@]}"; do
        if systemctl --user is-active --quiet "$service"; then
            log_success "$service (user) is running"
        else
            log_warning "$service (user) is not running"
        fi
    done
}

check_network() {
    log_info "Checking network..."
    
    if ping -c 1 archlinux.org &>/dev/null; then
        log_success "Internet connection working"
    else
        log_error "No internet connection"
    fi
    
    if command -v iwctl &>/dev/null; then
        log_success "iwd is available"
    else
        log_error "iwd not found"
    fi
}

check_audio() {
    log_info "Checking audio..."
    
    if pactl info &>/dev/null; then
        log_success "PulseAudio (pipewire) is working"
    else
        log_warning "Audio might not be working"
    fi
}

check_fonts() {
    log_info "Checking fonts..."
    
    if fc-list | grep -q "JetBrains Mono"; then
        log_success "JetBrains Mono font installed"
    else
        log_warning "JetBrains Mono font missing"
    fi
    
    if fc-list | grep -q "Fira Code"; then
        log_success "Fira Code font installed"
    else
        log_warning "Fira Code font missing"
    fi
}

main() {
    log_info "Verifying system setup..."
    
    check_packages
    check_services
    check_network
    check_audio
    check_fonts
    
    log_success "Verification complete!"
    log_info "Check above for any warnings or errors"
}

main