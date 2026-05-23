#!/bin/bash
# =============================================================================
#  MODULE 07 — AUR Applications
# =============================================================================
source "$(dirname "$0")/modules/00_common.sh"

print_module_header "AUR Applications"

if ! command -v yay &>/dev/null; then
    print_warn "yay not available — skipping all AUR applications"
    log_warn "All AUR applications skipped (yay missing)"
    print_done
    exit 0
fi

AUR_PACKAGES=(
    python-pywal16   # Color scheme generator
    obsidian         # Note-taking
    impala           # WiFi TUI
    bluetuith        # Bluetooth TUI
    qimgv            # Image viewer
    sioyek           # PDF viewer
)

for pkg in "${AUR_PACKAGES[@]}"; do
    yay_install "$pkg"
done

print_done
