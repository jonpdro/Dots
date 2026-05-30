#!/usr/bin/env bash

STYLE="$HOME/.config/waybar/style.css"
THEMES_DIR="$HOME/.config/waybar/themes"

mapfile -t themes < <(
    find "$THEMES_DIR" \
        -maxdepth 1 \
        -type f \
        -name "theme-*.css" \
        -printf "%f\n" |
    sort
)

if [[ ${#themes[@]} -eq 0 ]]; then
    echo "No themes found."
    exit 1
fi

current=$(basename "$(grep '^@import' "$STYLE" | cut -d'"' -f2)")

if [[ -z "$current" ]]; then
    echo "Could not detect current theme."
    exit 1
fi

current_index=-1

for i in "${!themes[@]}"; do
    if [[ "${themes[$i]}" == "$current" ]]; then
        current_index=$i
        break
    fi
done

if [[ $current_index -eq -1 ]]; then
    echo "Current theme '$current' not found."
    exit 1
fi

next_index=$(( (current_index + 1) % ${#themes[@]} ))
next="${themes[$next_index]}"

sed -i \
"0,/^@import /s|^@import \".*\";|@import \"$THEMES_DIR/$next\";|" \
"$STYLE"

pkill -SIGUSR2 waybar

echo "Switched to ${next%.css}"