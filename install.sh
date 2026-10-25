#!/usr/bin/env bash
# ==============================================================================
# ARCH LINUX HYPRLAND DYNAMIC THEME DOTFILES INSTALLER (install.sh)
# Replicates the complete system environment on any fresh Arch Linux machine:
# - Audio: PipeWire, WirePlumber, pavucontrol, pwvucontrol, playerctl
# - Network & Bluetooth: NetworkManager (nmtui), BlueZ (bluetoothctl), Blueman
# - Hyprland & Wayland: Hyprland, Waybar, Fuzzel, Kitty, Yazi, Neovim (LazyVim)
# - Wallpapers (Static & Animated): swaybg, swww, mpvpaper, ffmpeg, matugen, magick
# - Apps & Utilities: Chromium, Obsidian, VS Code, Thunar, Btop, Cava, Fastfetch
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
WALLPAPER_DEST="$HOME/Pictures/Wallpapers"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"

MODE="symlink"      # "symlink" (default) or "copy"
SKIP_PKGS=false

# Colors for terminal output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  --symlink       Symlink repo configs into ~/.config (default, ideal for Git tracking)
  --copy          Copy repo configs into ~/.config instead of symlinking
  --no-packages   Skip pacman/AUR package installation (only deploy configs & theme)
  -h, --help      Show this help message
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --symlink)     MODE="symlink" ;;
        --copy)        MODE="copy" ;;
        --no-packages) SKIP_PKGS=true ;;
        -h|--help)     usage; exit 0 ;;
        *)             err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [ "$(id -u)" -eq 0 ]; then
    err "Please do not run install.sh as root. It will prompt for sudo when needed."
    exit 1
fi

install_packages() {
    if [ "$SKIP_PKGS" = true ]; then
        info "Skipping package installation (--no-packages)."
        return
    fi

    if ! command -v pacman >/dev/null 2>&1; then
        warn "pacman not detected. Skipping Arch Linux package installation."
        return
    fi

    info "Installing complete Arch Linux package stack via pacman..."
    local pacman_pkgs=(
        # --- Hyprland & Wayland Session ---
        hyprland
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        qt5-wayland
        qt6-wayland
        polkit-gnome
        waybar
        fuzzel
        wl-clipboard
        cliphist
        grim
        slurp
        brightnessctl
        libnotify
        mako

        # --- Audio (PipeWire + WirePlumber + Controls) ---
        pipewire
        pipewire-pulse
        pipewire-alsa
        pipewire-jack
        wireplumber
        pavucontrol
        playerctl

        # --- Network (nmtui / nmcli) & Bluetooth (blueman / bluetoothctl) ---
        networkmanager
        network-manager-applet
        bluez
        bluez-utils
        blueman

        # --- Terminal, Shell & CLI Ecosystem ---
        kitty
        zsh
        zsh-syntax-highlighting
        zsh-autosuggestions
        starship
        fastfetch
        btop
        cava

        # --- File Manager (Yazi + Rich Previewers + Thunar) ---
        yazi
        ffmpeg
        ffmpegthumbnailer
        p7zip
        jq
        poppler
        fd
        ripgrep
        fzf
        zoxide
        resvg
        thunar

        # --- Neovim (LazyVim) & Build Dependencies ---
        neovim
        git
        base-devel
        nodejs
        npm
        unzip
        lazygit
        tree-sitter-cli

        # --- Dynamic Wallpaper & Theme Engine ---
        swaybg
        swww
        mpv
        python
        imagemagick

        # --- Desktop Applications (Configured in Hyprland & Yazi Openers) ---
        chromium
        obsidian
        code

        # --- Fonts & Icon Themes ---
        ttf-jetbrains-mono-nerd
        ttf-cascadia-code-nerd
        noto-fonts
        noto-fonts-emoji
        papirus-icon-theme
    )
    sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"

    # Check for AUR helper (yay or paru) for animated wallpapers & Material You engine
    local aur_helper=""
    if command -v yay >/dev/null 2>&1; then
        aur_helper="yay"
    elif command -v paru >/dev/null 2>&1; then
        aur_helper="paru"
    else
        info "Bootstrapping yay-bin AUR helper..."
        local tmp_yay
        tmp_yay="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay-bin.git "$tmp_yay/yay-bin"
        (cd "$tmp_yay/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp_yay"
        aur_helper="yay"
    fi

    if [ -n "$aur_helper" ]; then
        info "Installing AUR packages (swww, mpvpaper, matugen-bin, pwvucontrol)..."
        "$aur_helper" -S --needed --noconfirm swww mpvpaper matugen-bin pwvucontrol || \
            warn "Some optional AUR packages could not be built; fallback tools are already installed."
    fi
}

enable_services_and_shell() {
    if [ "$SKIP_PKGS" = true ]; then
        return
    fi

    info "Enabling system services (NetworkManager, Bluetooth, PipeWire)..."
    sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
    sudo systemctl enable --now bluetooth.service 2>/dev/null || true
    systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true

    # Install Oh My Zsh + plugins if ~/.oh-my-zsh is missing
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
    fi
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [ -d "$HOME/.oh-my-zsh" ]; then
        if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
            git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions" 2>/dev/null || true
        fi
        if [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true
        fi
    fi
}

deploy_item() {
    local src="$1"
    local dst="$2"

    # If destination already points to our source symlink, nothing to do
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        ok "Already linked: $dst"
        return
    fi

    # Backup existing config if present
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        local base_name
        base_name="$(basename "$dst")"
        info "Backing up existing $dst -> $BACKUP_DIR/$base_name"
        mv "$dst" "$BACKUP_DIR/$base_name"
    fi

    mkdir -p "$(dirname "$dst")"
    if [ "$MODE" = "symlink" ]; then
        ln -s "$src" "$dst"
        ok "Linked $dst -> $src"
    else
        cp -r "$src" "$dst"
        ok "Copied $src -> $dst"
    fi
}

deploy_configs() {
    info "Deploying configurations to $CONFIG_DEST ($MODE mode)..."
    mkdir -p "$CONFIG_DEST"

    local apps=(
        hypr
        waybar
        kitty
        yazi
        nvim
        fuzzel
        gtk-3.0
        gtk-4.0
        btop
        cava
        fastfetch
        matugen
    )

    for app in "${apps[@]}"; do
        if [ -e "$REPO_DIR/config/$app" ]; then
            deploy_item "$REPO_DIR/config/$app" "$CONFIG_DEST/$app"
        fi
    done

    if [ -f "$REPO_DIR/config/starship.toml" ]; then
        deploy_item "$REPO_DIR/config/starship.toml" "$CONFIG_DEST/starship.toml"
    fi

    if [ -f "$REPO_DIR/zsh/.zshrc" ]; then
        deploy_item "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
    fi

    # Ensure scripts are executable and compile native wal-video daemon
    chmod +x "$CONFIG_DEST/hypr/scripts/"*.sh "$CONFIG_DEST/hypr/scripts/"*.py 2>/dev/null || true
    if [ -f "$CONFIG_DEST/hypr/scripts/wal-video.c" ] && command -v gcc >/dev/null 2>&1; then
        gcc -O2 "$CONFIG_DEST/hypr/scripts/wal-video.c" -o "$CONFIG_DEST/hypr/scripts/wal-video" \
            $(pkg-config --cflags --libs gtk+-3.0 gtk-layer-shell-0) 2>/dev/null || true
    fi
    chmod +x "$REPO_DIR/script.sh" 2>/dev/null || true
}

deploy_wallpapers() {
    info "Setting up wallpapers in $WALLPAPER_DEST..."
    mkdir -p "$WALLPAPER_DEST"
    if [ -d "$REPO_DIR/wallpapers" ]; then
        cp -rn "$REPO_DIR/wallpapers/"* "$WALLPAPER_DEST/" 2>/dev/null || true
        ok "Wallpapers synced to $WALLPAPER_DEST"
    fi
}

bootstrap_theme() {
    info "Generating initial dynamic theme from default wallpaper..."
    local default_wp="$WALLPAPER_DEST/mi_wallpaper.png"
    if [ ! -f "$default_wp" ]; then
        default_wp="$(find "$WALLPAPER_DEST" -maxdepth 2 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \) | head -n 1 || true)"
    fi

    if [ -n "$default_wp" ] && [ -f "$default_wp" ]; then
        "$CONFIG_DEST/hypr/scripts/theme-switch.sh" "$default_wp"
        ok "Dynamic theme generated and applied from $(basename "$default_wp")"
    else
        warn "No wallpaper found in $WALLPAPER_DEST to bootstrap theme."
    fi
}

main() {
    echo -e "${GREEN}======================================================================${NC}"
    echo -e "${GREEN}   Arch Linux + Hyprland Dynamic Wallpaper Dotfiles Installer         ${NC}"
    echo -e "${GREEN}======================================================================${NC}"

    install_packages
    enable_services_and_shell
    deploy_configs
    deploy_wallpapers
    bootstrap_theme

    echo ""
    ok "Installation complete!"
    if [ -d "$BACKUP_DIR" ]; then
        info "Previous configurations were safely backed up to: $BACKUP_DIR"
    fi
    info "Press SUPER + SHIFT + W in Hyprland or run ./script.sh to change wallpapers and reload all app themes live."
}

main
