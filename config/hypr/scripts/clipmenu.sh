#!/usr/bin/env bash
selected=$(cliphist list | fuzzel --dmenu --prompt="󰅌 Clipboard: ")
if [ -n "$selected" ]; then
    echo "$selected" | cliphist decode | wl-copy
fi
