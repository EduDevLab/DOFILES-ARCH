#!/usr/bin/env bash
# ==============================================================================
# Switch keyboard layout for all keyboards and show on-screen Hyprland notification
# ==============================================================================

# Switch layout on all detected keyboard devices
while IFS= read -r kb; do
    if [ -n "$kb" ]; then
        hyprctl switchxkblayout "$kb" next >/dev/null 2>&1 || true
    fi
done < <(hyprctl devices -j | jq -r '.keyboards[].name')

# Get current active layout of the main keyboard (or fallback to first)
layout=$(hyprctl devices -j | jq -r '(.keyboards[] | select(.main == true) | .active_keymap) // (.keyboards[0].active_keymap)' | head -n 1)

# Format friendly display name
if [[ "$layout" =~ [Ss]panish|[Ll]atam|[Ee]spañol ]]; then
    label="Español (LATAM)"
elif [[ "$layout" =~ [Ee]nglish|[Uu][Ss] ]]; then
    label="English (US)"
else
    label="$layout"
fi

# Fetch current theme primary color or fallback to neon green
color_hex="19FF76"
if [ -f "$HOME/.config/hypr/colors.lua" ]; then
    extracted=$(grep -oP 'primary\s*=\s*"\K[^"]+' "$HOME/.config/hypr/colors.lua" 2>/dev/null)
    [ -n "$extracted" ] && color_hex="$extracted"
fi

# Send native Hyprland on-screen notification (duration 1500ms, icon 2)
hyprctl notify 2 1500 "rgb(${color_hex})" "Teclado: ${label}" >/dev/null 2>&1
