#!/bin/bash
# arch-update.sh

STATE_FILE="$HOME/.arch-update-state"

# ── Colors ────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
WHITE="\033[97m"
BG_HEADER="\033[48;5;24m"

# ── Helpers ───────────────────────────────────────────────────
println()  { printf "    %b\n" "$*"; }
blank()    { echo ""; }

header() {
    blank
    printf "  ${BG_HEADER}${BOLD}${WHITE}  󰣇  ARCH UPDATER  ${RESET}\n"
    blank
}

# ── State ─────────────────────────────────────────────────────
if [ -f "$STATE_FILE" ]; then
    days_since_update=$(cat "$STATE_FILE")
else
    days_since_update=0
fi

days_since_update=$((days_since_update + 1))

# ── Main logic ────────────────────────────────────────────────
if [ "$days_since_update" -eq 7 ]; then

    pacman_updates=$(checkupdates 2>/dev/null)
    aur_updates=$(yay -Qu 2>/dev/null)

    if [ -z "$pacman_updates" ] && [ -z "$aur_updates" ]; then
        header
        println "${GREEN}✔${RESET}  System is up to date."
        blank
        days_since_update=0
    else
        header
        println "󰅢  ${BOLD}${WHITE}New updates available${RESET}"
        blank

        if [ -n "$pacman_updates" ]; then
            println "${BLUE}󰮯  Official Repos${RESET}"
            blank
            while IFS= read -r pkg; do
                name=$(awk '{print $1}' <<< "$pkg")
                ver_old=$(awk '{print $2}' <<< "$pkg")
                ver_new=$(awk '{print $4}' <<< "$pkg")
                println "  ${GREEN}▸${RESET}  ${WHITE}$(printf '%-24s' "$name")${RESET}  ${DIM}$ver_old${RESET}  ${CYAN}→${RESET}  ${YELLOW}$ver_new${RESET}"
            done <<< "$pacman_updates"
            blank
        fi

        if [ -n "$aur_updates" ]; then
            println "${YELLOW}  AUR${RESET}"
            blank
            while IFS= read -r pkg; do
                name=$(awk '{print $1}' <<< "$pkg")
                ver_old=$(awk '{print $2}' <<< "$pkg")
                ver_new=$(awk '{print $4}' <<< "$pkg")
                println "  ${GREEN}▸${RESET}  ${WHITE}$(printf '%-24s' "$name")${RESET}  ${DIM}$ver_old${RESET}  ${CYAN}→${RESET}  ${YELLOW}$ver_new${RESET}"
            done <<< "$aur_updates"
            blank
        fi

        printf "  ${YELLOW}  Update now?${RESET} ${DIM}(y/n)${RESET}  "
        read -rp "" answer
        blank

        if [[ "$answer" == "y" ]]; then
            [ -n "$pacman_updates" ] && sudo pacman -Syu
            [ -n "$aur_updates" ]    && yay -Syu --aur
            days_since_update=0
        else
            println "${RED}✗${RESET}  Skipped. Counter reset."
            blank
            days_since_update=0
        fi
    fi

else
    header
    println "󰥔  ${DIM}Day ${RESET}${WHITE}${days_since_update}${RESET}${DIM} of 7${RESET}"
    println "   ${DIM}Next check in $((7 - days_since_update)) day(s)${RESET}"
    blank
fi

echo "$days_since_update" > "$STATE_FILE"