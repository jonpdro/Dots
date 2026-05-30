#!/bin/bash

# Audio device switcher for PipeWire (Arch + Hyprland)
# Usage:
#   sink-switcher.sh            → toggle between devices (manual keybind)
#   sink-switcher.sh --autostart → set best available sink at startup

MONITOR_SINK="alsa_output.pci-0000_04_00.1.HiFi__HDMI1__sink"
HEADPHONES_SINK="bluez_output.CC_14_BC_BA_31_3E.1"

headphones_available() {
    pactl list short sinks | awk '{print $2}' | grep -qxF "$HEADPHONES_SINK"
}

switch_to() {
    local sink="$1"
    local label="$2"

    pactl set-default-sink "$sink"

    pactl list short sink-inputs | awk '{print $1}' | while read -r id; do
        pactl move-sink-input "$id" "$sink" 2>/dev/null
    done

    notify-send -u low -t 2000 "Audio → $label"
}

# ── autostart ─────────────────────────────────────────────────────────────────

if [[ "$1" == "--autostart" ]]; then
    if headphones_available; then
        switch_to "$HEADPHONES_SINK" "Headphones 🎧"
    else
        switch_to "$MONITOR_SINK" "Monitor 🖥️"
    fi
    exit 0
fi

# ── toggle ────────────────────────────────────────────────────────────────────

CURRENT_SINK=$(pactl get-default-sink)

if [[ "$CURRENT_SINK" == "$MONITOR_SINK" ]]; then
    TARGET_SINK="$HEADPHONES_SINK"
    LABEL="Headphones 🎧"
else
    TARGET_SINK="$MONITOR_SINK"
    LABEL="Monitor 🖥️"
fi

if ! headphones_available && [[ "$TARGET_SINK" == "$HEADPHONES_SINK" ]]; then
    notify-send -u critical "No Headphones 🎧" \
        "\nAudio → Monitor 🖥️"
    exit 1
fi

switch_to "$TARGET_SINK" "$LABEL"
