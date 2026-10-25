#!/usr/bin/env bash
# ==============================================================================
# DYNAMIC WALLPAPER & SYSTEM THEME SWITCHER (Arch Linux + Hyprland)
# Supports: Static (.png, .jpg, .jpeg, .webp) & Animated (.gif, .mp4, .webm, .mkv)
# Targets: System (Hyprland, Fuzzel, GTK 3/4), Kitty, Waybar, Yazi, Neovim, Btop, Cava
# ==============================================================================

set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
CACHE_FILE="$HOME/.cache/current_wallpaper"
SCRIPTS_DIR="$HOME/.config/hypr/scripts"
PALETTE_GEN="$SCRIPTS_DIR/palette_gen.py"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/mi_wallpaper.png"

mkdir -p "$WALLPAPER_DIR" "$HOME/.cache"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [WALLPAPER_PATH]

Supported Formats:
  Static:   .png, .jpg, .jpeg, .webp
  Animated: .gif, .mp4, .webm, .mkv

Options:
  --init          Restore last wallpaper (or default) on session startup
  --random        Pick a random wallpaper from $WALLPAPER_DIR
  --select        Open interactive fuzzel menu to choose a wallpaper (default if no args)
  -h, --help      Show this help message
EOF
}

find_wallpapers() {
    find "$WALLPAPER_DIR" -maxdepth 2 -type f \( \
        -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \
        -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \
    \) | sort
}

select_wallpaper_menu() {
    mapfile -t files < <(find_wallpapers)
    if [ "${#files[@]}" -eq 0 ]; then
        notify-send "Dynamic Theme" "No wallpapers found in $WALLPAPER_DIR" 2>/dev/null || true
        exit 1
    fi

    local choices=""
    for f in "${files[@]}"; do
        choices+="${f#"$WALLPAPER_DIR"/}"$'\n'
    done

    local selected
    selected=$(printf "%s" "$choices" | fuzzel --dmenu --prompt="󰸉 Wallpaper: " --lines=10 --width=45) || exit 0
    if [ -z "$selected" ]; then
        exit 0
    fi
    echo "$WALLPAPER_DIR/$selected"
}

pick_random_wallpaper() {
    find_wallpapers | shuf -n 1
}

stop_video_daemons() {
    pkill -x mpvpaper >/dev/null 2>&1 || true
    pkill -x wal-video >/dev/null 2>&1 || true
    pkill -f "ffmpeg -nostdin -loglevel quiet -stream_loop -1" >/dev/null 2>&1 || true
}

start_video_wallpaper() {
    local wp="$1"
    if command -v mpvpaper >/dev/null 2>&1; then
        mpvpaper -f -o "no-audio loop hwdec=auto panscan=1.0" '*' "$wp" >/dev/null 2>&1 || true
        return 0
    fi

    # Build native wal-video layer-shell daemon on the fly if not yet compiled
    if [ ! -x "$SCRIPTS_DIR/wal-video" ] && [ -f "$SCRIPTS_DIR/wal-video.c" ]; then
        gcc -O2 "$SCRIPTS_DIR/wal-video.c" -o "$SCRIPTS_DIR/wal-video" \
            $(pkg-config --cflags --libs gtk+-3.0 gtk-layer-shell-0) >/dev/null 2>&1 || true
    fi

    if [ -x "$SCRIPTS_DIR/wal-video" ]; then
        nohup "$SCRIPTS_DIR/wal-video" "$wp" >/dev/null 2>&1 &
        disown
        return 0
    fi

    return 1
}

apply_wallpaper() {
    local wp="$1"
    local ext="${wp##*.}"
    ext="${ext,,}"

    case "$ext" in
        mp4|webm|mkv|avi|mov)
            # Video wallpaper -> use mpvpaper or native wal-video layer-shell daemon
            pkill -x swaybg >/dev/null 2>&1 || true
            pkill -x swww-daemon >/dev/null 2>&1 || true
            stop_video_daemons
            if ! start_video_wallpaper "$wp"; then
                if [ -f "/tmp/hypr_dynamic_wal_frame.png" ] && command -v swaybg >/dev/null 2>&1; then
                    nohup swaybg -i "/tmp/hypr_dynamic_wal_frame.png" -m fill >/dev/null 2>&1 &
                    disown
                fi
            fi
            ;;
        gif)
            # Animated GIF -> prefer swww, then mpvpaper / wal-video, then swaybg
            pkill -x swaybg >/dev/null 2>&1 || true
            stop_video_daemons
            if command -v swww >/dev/null 2>&1; then
                if ! pgrep -x "swww-daemon" >/dev/null 2>&1; then
                    swww-daemon --format xrgb >/dev/null 2>&1 &
                    sleep 0.3
                fi
                swww img "$wp" \
                    --transition-type grow \
                    --transition-pos 0.85,0.85 \
                    --transition-step 90 \
                    --transition-fps 60 >/dev/null 2>&1 || true
            elif ! start_video_wallpaper "$wp"; then
                if command -v swaybg >/dev/null 2>&1; then
                    nohup swaybg -i "$wp" -m fill >/dev/null 2>&1 &
                    disown
                fi
            fi
            ;;
        *)
            # Static image (.png, .jpg, .jpeg, .webp) -> kill video daemons to save 100% video RAM
            stop_video_daemons
            if command -v swww >/dev/null 2>&1; then
                pkill -x swaybg >/dev/null 2>&1 || true
                if ! pgrep -x "swww-daemon" >/dev/null 2>&1; then
                    swww-daemon --format xrgb >/dev/null 2>&1 &
                    sleep 0.3
                fi
                swww img "$wp" \
                    --transition-type grow \
                    --transition-pos 0.85,0.85 \
                    --transition-step 90 \
                    --transition-fps 60 >/dev/null 2>&1 || true
            elif command -v swaybg >/dev/null 2>&1; then
                pkill -x swaybg >/dev/null 2>&1 || true
                nohup swaybg -i "$wp" -m fill >/dev/null 2>&1 &
                disown
            fi
            ;;
    esac
}

reload_apps() {
    # 1. Hyprland borders & shadows
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl reload >/dev/null 2>&1 || true
    fi

    # 2. Kitty terminals (SIGUSR1 reloads config & colors live without closing windows)
    if pgrep -x kitty >/dev/null 2>&1; then
        pkill -USR1 -x kitty >/dev/null 2>&1 || true
    fi

    # 3. Waybar (SIGUSR2 reloads style.css live)
    if pgrep -x waybar >/dev/null 2>&1; then
        pkill -USR2 -x waybar >/dev/null 2>&1 || true
    fi

    # 4. Neovim (SIGUSR1 triggers Signal autocmd in lua/config/autocmds.lua)
    if pgrep -x nvim >/dev/null 2>&1; then
        pkill -USR1 -x nvim >/dev/null 2>&1 || true
    fi

    # 5. Cava audio visualizer (SIGUSR1 reloads colors live)
    if pgrep -x cava >/dev/null 2>&1; then
        pkill -USR1 -x cava >/dev/null 2>&1 || true
    fi
}

main() {
    local target_wp=""
    local mode="interactive"

    if [ $# -gt 0 ]; then
        case "$1" in
            --init)
                mode="init"
                if [ -f "$CACHE_FILE" ] && [ -f "$(cat "$CACHE_FILE")" ]; then
                    target_wp="$(cat "$CACHE_FILE")"
                else
                    target_wp="$DEFAULT_WALLPAPER"
                fi
                ;;
            --random)
                mode="random"
                target_wp="$(pick_random_wallpaper)"
                ;;
            --select)
                mode="interactive"
                target_wp="$(select_wallpaper_menu)"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                mode="direct"
                target_wp="$(realpath -m "$1")"
                ;;
        esac
    else
        target_wp="$(select_wallpaper_menu)"
    fi

    if [ -z "$target_wp" ] || [ ! -f "$target_wp" ]; then
        echo "Error: Wallpaper not found: ${target_wp:-<empty>}" >&2
        exit 1
    fi

    # Save current wallpaper state
    echo "$target_wp" > "$CACHE_FILE"

    # Generate all dynamic theme files (extracts a frame automatically if GIF/video)
    python3 "$PALETTE_GEN" "$target_wp"

    # Set wallpaper on screen (if inside a Wayland session)
    if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        apply_wallpaper "$target_wp"
        reload_apps
        if [ "$mode" != "init" ] && command -v notify-send >/dev/null 2>&1; then
            local icon_path="$target_wp"
            if [ -f "/tmp/hypr_dynamic_wal_frame.png" ]; then
                icon_path="/tmp/hypr_dynamic_wal_frame.png"
            fi
            notify-send -u low -i "$icon_path" "Dynamic Theme Applied" "Wallpaper: $(basename "$target_wp")" 2>/dev/null || true
        fi
    fi
}

main "$@"
