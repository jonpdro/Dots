#!/bin/bash

# Post-Installation Setup Script for Arch Linux
# Designed to run in chroot after archinstall

set -e  # Exit on any error

# Colors for output
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Update system
update_system() {
    log_info "Updating system..."
    pacman -Syu --noconfirm
    log_success "System updated successfully"
}

# Install essential build tools
install_build_tools() {
    log_info "Installing essential build tools..."
    pacman -S --needed --noconfirm git base-devel
    log_success "Build tools installed successfully"
}

# Install yay AUR helper
install_yay() {
    log_info "Installing yay AUR helper..."
    
    if command -v yay &> /dev/null; then
        log_info "yay is already installed"
        return 0
    fi
    
    # Create temporary user for yay installation if needed
    if ! id -u builder &> /dev/null; then
        useradd -m -G wheel -s /bin/bash builder
        echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder
    fi
    
    # Install yay as builder user
    sudo -u builder bash << 'EOF'
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
EOF
    
    log_success "yay installed successfully"
}

# Install core packages
install_core_packages() {
    log_info "Installing core packages..."
    
    pacman -S --needed --noconfirm \
        hyprland \
        qbittorrent \
        rofi \
        dunst \
        wireplumber \
        pipewire \
        pipewire-pulse \
        pipewire-alsa \
        kate \
        waybar \
        bluez \
        bluez-utils \
        xdg-desktop-portal-hyprland \
        slurp \
        grim \
        wl-clipboard \
        foot || {
            log_error "Failed to install some core packages"
            return 1
        }
    
    log_success "Core packages installed successfully"
}

# Install AUR packages
install_aur_packages() {
    log_info "Installing AUR packages..."
    
    # Note: Installing as root with yay can be problematic
    # Better to use a build user
    sudo -u builder yay -S --needed --noconfirm \
        pywal16 \
        yazi \
        hyprlock \
        hypridle \
        hyprpaper \
        mpv \
        neovim \
        qimgv \
        impala \
        wiremix || {
            log_warning "Some AUR packages may have failed to install"
        }
    
    log_success "AUR packages installation completed"
}

# Install fonts from official repositories
install_official_fonts() {
    log_info "Installing fonts from official repositories..."
    
    pacman -S --needed --noconfirm \
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
        gsfonts || {
            log_warning "Some fonts may have failed to install"
        }
    
    log_success "Official repository fonts installed"
}

# Install fonts from AUR
install_aur_fonts() {
    log_info "Installing fonts from AUR..."
    
    sudo -u builder yay -S --needed --noconfirm ttf-ms-fonts || {
        log_warning "AUR fonts installation failed"
    }
    
    log_success "AUR fonts installation completed"
}

# Rebuild font cache
rebuild_font_cache() {
    log_info "Rebuilding font cache..."
    fc-cache -fv
    log_success "Font cache rebuilt successfully"
}

# Enable system services
enable_services() {
    log_info "Enabling system services..."
    
    # Enable Bluetooth
    systemctl enable bluetooth
    systemctl start bluetooth
    
    # Enable pipewire services
    systemctl --user enable wireplumber
    systemctl --user enable pipewire
    systemctl --user enable pipewire-pulse
    
    # Enable iwd (if installed separately)
    if pacman -Q iwd &> /dev/null; then
        systemctl enable iwd
        systemctl start iwd
    fi
    
    log_success "System services enabled"
}

# Set up user directory for pipewire (if in chroot with user)
setup_user_services() {
    local username=$(ls /home | head -1)  # Get first user
    
    if [[ -n "$username" ]]; then
        log_info "Setting up user services for $username"
        
        # Enable user services for the first user found
        systemctl enable --now systemd-logind
        log_success "User services setup initiated"
    else
        log_warning "No user found in /home, user services will need manual setup"
    fi
}

# Main execution function
main() {
    log_info "Starting post-installation setup..."
    
    check_root
    
    # Execute all steps in order
    update_system
    install_build_tools
    install_yay
    install_core_packages
    install_aur_packages
    install_official_fonts
    install_aur_fonts
    rebuild_font_cache
    enable_services
    setup_user_services
    
    log_success "Post-installation setup completed successfully!"
    log_info "You can now reboot into your new system"
    echo ""
    log_info "After reboot, remember to:"
    log_info "1. Connect to WiFi using: iwctl station wlan0 connect SSID"
    log_info "2. Configure Hyprland and your other applications"
    log_info "3. Set up Impala for network management"
}

# Handle script interruption
cleanup() {
    log_warning "Script interrupted"
    exit 1
}

# Set trap for cleanup
trap cleanup INT TERM

# Run main function
main