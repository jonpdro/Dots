#!/bin/bash

# Font Installation Script for Arch Linux
# Installs a comprehensive set of fonts from official repos and AUR

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if yay is installed
check_yay() {
    if ! command -v yay &> /dev/null; then
        log_error "yay is not installed. Please install yay first."
        log_info "You can install yay with:"
        echo "  cd /tmp"
        echo "  git clone https://aur.archlinux.org/yay.git"
        echo "  cd yay"
        echo "  makepkg -si"
        exit 1
    fi
}

# Install fonts from official repositories
install_official_fonts() {
    log_info "Installing fonts from official repositories..."
    
    sudo pacman -S --needed --noconfirm \
        adobe-source-code-pro-fonts \
        adobe-source-sans-fonts \
        adobe-source-serif-fonts \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji \
        noto-fonts-extra \
        ttf-ubuntu-font-family \
        ttf-nerd-fonts-symbols \
        ttf-nerd-fonts-symbols-common \
        ttf-jetbrains-mono-nerd \
        ttf-firacode-nerd \
        woff2-font-awesome \
        gsfonts
    
    log_success "Official repository fonts installed successfully"
}

# Install fonts from AUR
install_aur_fonts() {
    log_info "Installing fonts from AUR..."
    
    yay -S --needed --noconfirm ttf-ms-fonts
    
    log_success "AUR fonts installed successfully"
}

# Rebuild font cache
rebuild_font_cache() {
    log_info "Rebuilding font cache..."
    fc-cache -fv
    log_success "Font cache rebuilt successfully"
}

# List installed fonts
list_fonts() {
    log_info "Installed font families:"
    echo ""
    fc-list : family | sort -u | head -20
    echo ""
    log_info "Showing first 20 families. Run 'fc-list : family | sort -u' to see all."
}

# Main execution
main() {
    echo ""
    log_info "Starting font installation..."
    echo ""
    
    # Check for yay
    check_yay
    echo ""
    
    # Install fonts
    install_official_fonts
    echo ""
    
    install_aur_fonts
    echo ""
    
    rebuild_font_cache
    echo ""
    
    list_fonts
    echo ""
    
    log_success "All fonts installed successfully!"
    log_info "Font list:"
    echo "  ✓ Adobe Source Code Pro (Monospace)"
    echo "  ✓ Adobe Source Sans (Sans-serif)"
    echo "  ✓ Adobe Source Serif (Serif)"
    echo "  ✓ Noto Fonts (All variants + CJK + Emoji)"
    echo "  ✓ Ubuntu Font Family"
    echo "  ✓ Nerd Fonts Symbols"
    echo "  ✓ JetBrains Mono Nerd Font"
    echo "  ✓ Fira Code Nerd Font"
    echo "  ✓ Font Awesome"
    echo "  ✓ Ghostscript Fonts"
    echo "  ✓ Microsoft Fonts (Arial, Times New Roman, etc.)"
}

# Run main function
main