#!/bin/bash

# Audio device switcher for PipeWire (Arch + Hyprland)
# Toggles between HDMI1 monitor and Bluetooth headphones

MONITOR_SINK="alsa_output.pci-0000_04_00.1.HiFi__HDMI1__sink"
HEADPHONES_SINK="bluez_output.CC_14_BC_BA_31_3E.1"

# ── toggle ────────────────────────────────────────────────────────────────────

CURRENT_SINK=$(pactl get-default-sink)

if [[ "$CURRENT_SINK" == "$MONITOR_SINK" ]]; then
    TARGET_SINK="$HEADPHONES_SINK"
    LABEL="Headphones 🎧"
else
    TARGET_SINK="$MONITOR_SINK"
    LABEL="Monitor 🖥️"
fi

# ── verify target is available ────────────────────────────────────────────────

if ! pactl list short sinks | awk '{print $2}' | grep -qxF "$TARGET_SINK"; then
    notify-send -u critical "Audio Switch Failed" \
        "$([ "$TARGET_SINK" = "$HEADPHONES_SINK" ] && echo "Headphones not found — are they on and connected?" || echo "Monitor sink not found.")"
    exit 1
fi

# ── switch ────────────────────────────────────────────────────────────────────

pactl set-default-sink "$TARGET_SINK"

pactl list short sink-inputs | awk '{print $1}' | while read -r id; do
    pactl move-sink-input "$id" "$TARGET_SINK" 2>/dev/null
done

notify-send -u low -t 2000 "Audio → $LABEL"
