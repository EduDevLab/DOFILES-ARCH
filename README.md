# Arch Linux + Hyprland Dynamic Wallpaper Dotfiles

Minimalist, terminal-first **Arch Linux + Hyprland** dotfiles featuring **live wallpaper-driven dynamic theming** across the system and terminal/GUI applications without restarting your workflow.

---

## ✨ Features & Dynamically Themed Applications

Whenever you change your wallpaper (via `SUPER + SHIFT + W` or `./script.sh`), dominant and harmonic colors are automatically extracted and live-reloaded across:

| Target | Dynamic Config File | Live Reload Mechanism |
| :--- | :--- | :--- |
| **Hyprland** | `config/hypr/colors.lua` | `hyprctl reload` (active gradient borders & window glow shadows via native Lua API) |
| **Waybar** | `config/waybar/colors.css` & `config.jsonc` | `pkill -SIGUSR2 waybar` (floating bar, workspace pills, tooltips & calendar) |
| **Kitty** | `config/kitty/current-theme.conf` | `pkill -SIGUSR1 kitty` (ANSI 0–15 palette, cursor, tabs, background) |
| **Yazi** | `config/yazi/theme.toml` | Full UI theme (`[mgr]`, `[mode]`, `[status]`, `[which]`, `[filetype]`) |
| **Neovim** | `config/nvim/lua/config/palette.lua` | `pkill -SIGUSR1 nvim` (`Signal` autocmd reloads UI, Treesitter, LSP, Telescope & Neo-tree in real time) |
| **Fuzzel** | `config/fuzzel/colors.ini` & `fuzzel.ini` | App launcher & clipboard selector (`SUPER + SPACE`, `SUPER + V`) |
| **GTK 3 & 4 / Thunar** | `config/gtk-3.0/gtk.css` & `config/gtk-4.0/gtk.css` | CSS `@define-color` accent and surface variables |
| **Btop & Cava** | `config/btop/themes/dynamic.theme` & `config/cava/config` | System monitor theme & audio visualizer 8-stop gradient |

---

## 📂 Repository Structure

```text
dotfiles/
├── install.sh                 # Arch Linux installer, backup & symlink deployer
├── script.sh                  # Dynamic wallpaper & theme switcher entrypoint
├── README.md                  # Documentation
├── wallpapers/                # Default wallpapers (mi_wallpaper.png, etc.)
├── zsh/
│   └── .zshrc                 # Zsh configuration
└── config/
    ├── hypr/                  # hyprland.lua, colors.lua, scripts/ (theme-switch.sh, palette_gen.py, wal-video.c)
    ├── waybar/                # config.jsonc, style.css, colors.css
    ├── kitty/                 # kitty.conf, current-theme.conf
    ├── yazi/                  # yazi.toml, keymap.toml, theme.toml
    ├── nvim/                  # LazyVim configuration with live SIGUSR1 colorscheme reload
    ├── fuzzel/                # fuzzel.ini, colors.ini
    ├── gtk-3.0/               # gtk.css, settings.ini, thunar.css
    ├── gtk-4.0/               # gtk.css, settings.ini, thunar.css
    ├── btop/                  # btop.conf, themes/dynamic.theme
    ├── cava/                  # config
    ├── fastfetch/             # config.jsonc
    ├── matugen/               # config.toml
    └── starship.toml
```

---

## 🚀 Installation (`install.sh`)

Clone this repository on any fresh Arch Linux machine and run `./install.sh`:

```bash
git clone https://github.com/EduDevLab/DOFILES-ARCH.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh script.sh
./install.sh
```

### What `install.sh` Installs & Configures Automatically
- **Hyprland & Wayland Core**: `hyprland`, `waybar`, `fuzzel`, `xdg-desktop-portal-hyprland`, `polkit-gnome`, `wl-clipboard`, `cliphist`, `grim`, `slurp`, `brightnessctl`, `mako`, `libnotify`
- **Audio (`PipeWire` Stack)**: `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `pipewire-jack`, `wireplumber`, `pwvucontrol`, `pavucontrol`, `playerctl` (+ enables PipeWire user services)
- **Network & Bluetooth**: `networkmanager` (`nmtui` / `nmcli`), `bluez`, `bluez-utils` (`bluetoothctl`), `blueman` (`blueman-manager`) (+ enables `NetworkManager` & `bluetooth` systemd services)
- **Terminal, Editor & File Manager**: `kitty`, `zsh` (+ Oh My Zsh & plugins), `starship`, `yazi` (+ `ffmpegthumbnailer`, `poppler`, `jq`, `fd`, `ripgrep`, `fzf`, `zoxide`), `neovim` (+ `lazygit`, `tree-sitter-cli`, `nodejs`, `npm`), `btop`, `cava`, `fastfetch`
- **Desktop Apps & Fonts**: `chromium`, `obsidian`, `code`, `thunar`, `ttf-jetbrains-mono-nerd`, `ttf-cascadia-code-nerd`, `papirus-icon-theme`
- **Static & Animated Wallpaper Engine**: `swww`, `mpvpaper`, `swaybg`, `ffmpeg`, `imagemagick`, `matugen-bin`

### Installer Options
- `./install.sh --symlink` *(default)*: Installs packages, backs up any existing `~/.config/<app>` to `~/.config-backup-<timestamp>`, and symlinks `~/dotfiles/config/*` into `~/.config/*`.
- `./install.sh --copy`: Copies configuration files instead of creating symlinks.
- `./install.sh --no-packages`: Skips `pacman`/`yay` package installation and only deploys configs + generates the initial theme.

---

## 🎨 Switching Wallpapers & Themes (`script.sh`)

Put your static (`.png`, `.jpg`, `.jpeg`, `.webp`) or animated (`.gif`, `.mp4`, `.webm`, `.mkv`) wallpapers inside `~/Pictures/Wallpapers/` and use either keybindings or the CLI:

```bash
# Open interactive Fuzzel menu to pick a wallpaper from ~/Pictures/Wallpapers
./script.sh --select

# Apply a static or animated wallpaper directly
./script.sh ~/Pictures/Wallpapers/mi_wallpaper.png
./script.sh ~/Pictures/Wallpapers/cyberpunk_loop.mp4

# Pick a random wallpaper from ~/Pictures/Wallpapers
./script.sh --random

# Restore the last active wallpaper on session startup
./script.sh --init
```

---

## ⌨️ Keybindings (`Hyprland`)

| Keybind | Action |
| :--- | :--- |
| `SUPER + RETURN` / `SUPER + T` | Open **Kitty** terminal (tiled, adjusts to screen layout) |
| `SUPER + SHIFT + RETURN` / `SUPER + ALT + RETURN` | Open **Floating Kitty** terminal (centered floating popup) |
| `SUPER + ESC` | Open **Btop** system monitor (floating window) |
| `SUPER + E` | Open **Yazi** file manager (`T` / `Ctrl+T` inside Yazi opens terminal in cwd) |
| `SUPER + C` | Open **Neovim** editor |
| `SUPER + W` | Open **Chromium** browser |
| `SUPER + SPACE` / `SUPER + D` | Open **Fuzzel** application launcher |
| `SUPER + V` | Open **Clipboard history** (`cliphist` + `fuzzel`) |
| `SUPER + SHIFT + W` | **Interactive Wallpaper & Dynamic Theme Switcher** (`fuzzel`) |
| `SUPER + ALT + W` | **Random Wallpaper & Dynamic Theme Switcher** |
| `SUPER + Q` | Close active window |
| `SUPER + F` / `SUPER + ALT + F` | Fullscreen / Maximize |
| `SUPER + ALT + SPACE` | Toggle floating window |
| `SHIFT + RETURN` | **Switch keyboard layout** (US English ⇄ Latin American Spanish with on-screen notification) |
| `SUPER + L` | **Suspend & Lock to SDDM** (returns to SDDM login screen & suspends PC; restores session on login) |
| `SUPER + SHIFT + L` | **Lock to SDDM** (switches to SDDM login screen without suspending) |
| `SUPER + SHIFT + S` / `Print` | Screenshot region (clipboard / `~/Pictures/Screenshots`) |
| `SUPER + SHIFT + R` | Reload Hyprland configuration |


