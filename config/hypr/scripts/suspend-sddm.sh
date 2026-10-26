#!/usr/bin/env bash
# ==============================================================================
# Switch to SDDM Greeter (Lock Session) & Suspend Machine
# SDDM's ReuseSession=true restores the active Hyprland session upon login.
# ==============================================================================

# 1. Switch active seat to SDDM login screen (sddm-astronaut-theme)
busctl call org.freedesktop.DisplayManager \
    /org/freedesktop/DisplayManager/Seat0 \
    org.freedesktop.DisplayManager.Seat \
    SwitchToGreeter >/dev/null 2>&1 || true

# 2. Suspend the system unless --lock-only was requested
if [[ "${1:-}" != "--lock-only" ]]; then
    sleep 1
    systemctl suspend
fi
