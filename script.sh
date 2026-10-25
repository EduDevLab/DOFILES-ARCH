#!/usr/bin/env bash
# ==============================================================================
# SCRIPT.SH - DYNAMIC WALLPAPER & SYSTEM THEME CONTROLLER
# Wrapper & standalone entrypoint for ~/.config/hypr/scripts/theme-switch.sh
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED_SWITCHER="$HOME/.config/hypr/scripts/theme-switch.sh"
REPO_SWITCHER="$REPO_DIR/config/hypr/scripts/theme-switch.sh"

if [ -x "$INSTALLED_SWITCHER" ]; then
    exec "$INSTALLED_SWITCHER" "$@"
elif [ -f "$REPO_SWITCHER" ]; then
    exec bash "$REPO_SWITCHER" "$@"
else
    echo "Error: theme-switch.sh not found in ~/.config/hypr/scripts/ or $REPO_DIR/config/hypr/scripts/" >&2
    exit 1
fi
