#!/bin/bash
# =============================================================================
#  MODULE 01 — System Update
# =============================================================================
source "$(dirname "$0")/modules/00_common.sh"

print_module_header "System Update"

run "Full system upgrade (pacman -Syu)" sudo pacman -Syu --noconfirm

print_done
