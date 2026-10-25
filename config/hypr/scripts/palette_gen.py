#!/usr/bin/env python3
"""
Dynamic Wallpaper Palette Generator for Arch Linux + Hyprland
Extracts dominant vibrant colors from a wallpaper using matugen (if installed)
or ImageMagick (magick/convert) and generates cohesive dark-obsidian theme files for:
- Hyprland (~/.config/hypr/colors.conf)
- Waybar (~/.config/waybar/colors.css & config.jsonc calendar)
- Kitty (~/.config/kitty/current-theme.conf)
- Yazi (~/.config/yazi/theme.toml)
- Neovim (~/.config/nvim/lua/config/palette.lua)
- Fuzzel (~/.config/fuzzel/fuzzel.ini & colors.ini)
- GTK 3.0 & 4.0 (~/.config/gtk-3.0/gtk.css, ~/.config/gtk-4.0/gtk.css)
- Btop (~/.config/btop/themes/dynamic.theme)
- Cava (~/.config/cava/config)
"""

import colorsys
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    h = hex_str.lstrip("#")
    if len(h) >= 6:
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return 0, 255, 102


def rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{max(0, min(255, int(round(r)))):02X}{max(0, min(255, int(round(g)))):02X}{max(0, min(255, int(round(b)))):02X}"


def hsv_to_hex(h_deg: float, s: float, v: float) -> str:
    h = (h_deg % 360.0) / 360.0
    s = max(0.0, min(1.0, s))
    v = max(0.0, min(1.0, v))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return rgb_to_hex(int(r * 255), int(g * 255), int(b * 255))


def hex_to_hsv(hex_str: str) -> tuple[float, float, float]:
    r, g, b = hex_to_rgb(hex_str)
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    return h * 360.0, s, v


def rgba_css(hex_str: str, alpha: float) -> str:
    r, g, b = hex_to_rgb(hex_str)
    return f"rgba({r}, {g}, {b}, {alpha})"


ANIMATED_EXTS = {".gif", ".mp4", ".webm", ".mkv", ".avi", ".mov"}


def prepare_image_for_analysis(image_path: str) -> str:
    """If the wallpaper is an animated GIF or video, extract a representative frame to /tmp."""
    ext = Path(image_path).suffix.lower()
    if ext not in ANIMATED_EXTS:
        return image_path

    tmp_frame = "/tmp/hypr_dynamic_wal_frame.png"
    ffmpeg_bin = shutil.which("ffmpeg")
    magick_bin = shutil.which("magick") or shutil.which("convert")

    # Try ffmpeg first (fast for .mp4, .webm, .mkv, and .gif)
    if ffmpeg_bin:
        for seek in ("00:00:01", "00:00:00"):
            try:
                subprocess.run(
                    [
                        ffmpeg_bin,
                        "-y",
                        "-ss",
                        seek,
                        "-i",
                        image_path,
                        "-frames:v",
                        "1",
                        "-q:v",
                        "2",
                        tmp_frame,
                    ],
                    capture_output=True,
                    check=True,
                    timeout=10,
                )
                if os.path.isfile(tmp_frame) and os.path.getsize(tmp_frame) > 0:
                    return tmp_frame
            except Exception:
                continue

    # Fallback to ImageMagick first frame [0] (works well for .gif / animated .webp)
    if magick_bin:
        try:
            subprocess.run(
                [magick_bin, f"{image_path}[0]", tmp_frame],
                capture_output=True,
                check=True,
                timeout=10,
            )
            if os.path.isfile(tmp_frame) and os.path.getsize(tmp_frame) > 0:
                return tmp_frame
        except Exception:
            pass

    return image_path


def extract_dominant_hue_magick(image_path: str) -> tuple[float, float]:
    """Use ImageMagick histogram to extract the most vibrant dominant hue and saturation."""
    magick_bin = shutil.which("magick") or shutil.which("convert")
    if not magick_bin:
        return 144.0, 0.95  # Fallback to Emerald/Green Lantern

    target_img = prepare_image_for_analysis(image_path)
    try:
        cmd = [
            magick_bin,
            f"{target_img}[0]",
            "-resize",
            "120x120!",
            "-quantize",
            "sRGB",
            "-colors",
            "32",
            "-format",
            "%c",
            "histogram:info:-",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=10)
        lines = res.stdout.splitlines()
    except Exception:
        return 144.0, 0.95

    pattern = re.compile(r"^\s*(\d+):.*#([0-9A-Fa-f]{6})")
    # Bucket hues into 12 sectors (30 deg each) to find the strongest vibrant color cluster
    buckets = [{"weight": 0.0, "h_sum": 0.0, "max_s": 0.0} for _ in range(12)]

    for line in lines:
        m = pattern.search(line)
        if not m:
            continue
        count = int(m.group(1))
        hex_col = "#" + m.group(2)
        h, s, v = hex_to_hsv(hex_col)

        # Ignore dark shadows, near-whites, or muted slate/gray backgrounds
        if v < 0.20 or s < 0.25:
            continue

        # Strongly favor high-chroma focal accents over large muted background areas
        vibrancy = (s ** 3.8) * (v ** 1.5)
        weight = count * vibrancy
        b_idx = int(h // 30) % 12
        buckets[b_idx]["weight"] += weight
        buckets[b_idx]["h_sum"] += h * weight
        if s > buckets[b_idx]["max_s"]:
            buckets[b_idx]["max_s"] = s

    best_bucket = max(buckets, key=lambda b: b["weight"])
    if best_bucket["weight"] <= 0:
        # Monochrome / grayscale wallpaper fallback
        return 144.0, 0.25

    avg_h = best_bucket["h_sum"] / best_bucket["weight"]
    # Keep accents vivid and punchy on dark obsidian backgrounds
    vivid_s = max(0.90, min(1.0, best_bucket["max_s"] * 1.1))
    return avg_h % 360.0, vivid_s


def extract_hue_matugen(image_path: str) -> tuple[float, float] | None:
    """If matugen is installed, extract the primary hue from its Material You output."""
    matugen_bin = shutil.which("matugen")
    if not matugen_bin:
        return None
    target_img = prepare_image_for_analysis(image_path)
    try:
        res = subprocess.run(
            [matugen_bin, "image", target_img, "-j", "hex"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )
        data = json.loads(res.stdout)
        primary_hex = (
            data.get("colors", {}).get("dark", {}).get("primary")
            or data.get("colors", {}).get("primary", {}).get("dark")
        )
        if primary_hex:
            h, s, _ = hex_to_hsv(primary_hex)
            return h, max(0.75, min(1.0, s * 1.25))
    except Exception:
        pass
    return None


def build_palette(image_path: str) -> dict[str, str]:
    mat_res = extract_hue_matugen(image_path)
    if mat_res is not None:
        h, s_base = mat_res
    else:
        h, s_base = extract_dominant_hue_magick(image_path)

    # Construct cohesive dark-obsidian + glowing neon/accent palette around Hue `h`
    p = {
        "hue": round(h, 2),
        # Obsidian dark surfaces tinted with the wallpaper hue
        "bg": hsv_to_hex(h, 0.55 * s_base, 0.045),
        "bg_alt": hsv_to_hex(h, 0.55 * s_base, 0.09),
        "bg_highlight": hsv_to_hex(h, 0.58 * s_base, 0.15),
        "bg_visual": hsv_to_hex(h, 0.85 * s_base, 0.30),
        "cursor_line": hsv_to_hex(h, 0.55 * s_base, 0.115),
        # Borders
        "border": hsv_to_hex((h + 6) % 360, 0.90 * s_base, 0.58),
        "border_glow": hsv_to_hex(h, 0.95 * s_base, 1.00),
        "border_inactive": hsv_to_hex(h, 0.65 * s_base, 0.16),
        # Foregrounds
        "fg": hsv_to_hex(h, 0.08 * s_base, 0.96),
        "fg_dim": hsv_to_hex(h, 0.18 * s_base, 0.62),
        "fg_bright": "#FFFFFF",
        # Primary & harmonic accents
        "primary": hsv_to_hex(h, 0.95 * s_base, 1.00),
        "secondary": hsv_to_hex((h + 10) % 360, 0.92 * s_base, 0.60),
        "tertiary": hsv_to_hex((h + 28) % 360, 0.85 * s_base, 0.95),
        "neon_green": hsv_to_hex(h, 0.95 * s_base, 1.00),
        "emerald": hsv_to_hex((h + 10) % 360, 0.92 * s_base, 0.60),
        "mint": hsv_to_hex((h - 6) % 360, 0.45 * s_base, 0.88),
        "lime": hsv_to_hex((h - 16) % 360, 0.42 * s_base, 0.96),
        "teal": hsv_to_hex((h + 24) % 360, 0.88 * s_base, 0.98),
        "cyan": hsv_to_hex((h + 42) % 360, 0.72 * s_base, 0.96),
        "yellow": hsv_to_hex((h - 28) % 360, 0.28 * s_base, 0.98),
        "gold": "#CEC06B",
        "error": "#FF5555",
        "warning": "#FFAA33",
        "comment": hsv_to_hex(h, 0.25 * s_base, 0.45),
        # Terminal ANSI 0-15
        "color0": hsv_to_hex(h, 0.40 * s_base, 0.05),
        "color1": "#FF5555",
        "color2": hsv_to_hex(h, 0.75 * s_base, 0.88),
        "color3": hsv_to_hex((h - 20) % 360, 0.50 * s_base, 0.95),
        "color4": hsv_to_hex((h + 20) % 360, 0.65 * s_base, 0.82),
        "color5": hsv_to_hex((h + 45) % 360, 0.60 * s_base, 0.85),
        "color6": hsv_to_hex((h + 15) % 360, 0.55 * s_base, 0.88),
        "color7": hsv_to_hex(h, 0.10 * s_base, 0.88),
        "color8": hsv_to_hex(h, 0.20 * s_base, 0.55),
        "color9": "#FF7777",
        "color10": hsv_to_hex(h, 0.85 * s_base, 0.98),
        "color11": hsv_to_hex((h - 25) % 360, 0.35 * s_base, 1.00),
        "color12": hsv_to_hex((h + 22) % 360, 0.45 * s_base, 0.92),
        "color13": hsv_to_hex((h + 48) % 360, 0.50 * s_base, 0.94),
        "color14": hsv_to_hex((h + 16) % 360, 0.48 * s_base, 0.95),
        "color15": "#FFFFFF",
    }
    return p


def write_hyprland(config_dir: Path, p: dict[str, str]) -> None:
    c_prim = p["primary"].lstrip("#")
    c_sec = p["secondary"].lstrip("#")
    c_inact = p["border_inactive"].lstrip("#")
    lua_content = f"""-- ==============================================================================
-- HYPRLAND DYNAMIC COLORS (Auto-generated from Wallpaper - Hyprland 0.56+ Lua)
-- ==============================================================================
return {{
    primary         = "{c_prim}",
    secondary       = "{c_sec}",
    active_border_1 = "rgba({c_prim}ee)",
    active_border_2 = "rgba({c_sec}ee)",
    inactive_border = "rgba({c_inact}aa)",
    shadow_active   = "rgba({c_prim.lower()}33)",
    shadow_inactive = "rgba(00000066)",
}}
"""
    target = config_dir / "hypr" / "colors.lua"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(lua_content)


def write_waybar(config_dir: Path, p: dict[str, str]) -> None:
    css = f"""/* ==============================================================================
   WAYBAR DYNAMIC COLORS (Auto-generated from Wallpaper)
   ============================================================================== */
@define-color bg_main {rgba_css(p["bg"], 0.82)};
@define-color bg_tooltip {rgba_css(p["bg_alt"], 0.95)};
@define-color bg_workspaces {rgba_css(p["bg_highlight"], 0.45)};
@define-color bg_window {rgba_css(p["bg_highlight"], 0.40)};
@define-color bg_clock {rgba_css(p["bg_highlight"], 0.60)};
@define-color bg_module {rgba_css(p["bg_highlight"], 0.50)};
@define-color bg_hover {rgba_css(p["bg_visual"], 0.65)};

@define-color border_subtle {rgba_css(p["primary"], 0.25)};
@define-color border_clock {rgba_css(p["primary"], 0.35)};
@define-color glow_active {rgba_css(p["primary"], 0.55)};
@define-color glow_hover {rgba_css(p["primary"], 0.30)};

@define-color fg_main {p["fg"]};
@define-color fg_dim {p["fg_dim"]};
@define-color fg_dark {p["bg"]};
@define-color primary {p["primary"]};
@define-color secondary {p["secondary"]};
@define-color tertiary {p["tertiary"]};
@define-color mint {p["mint"]};
@define-color lime {p["lime"]};
@define-color teal {p["teal"]};
@define-color error {p["error"]};
"""
    waybar_dir = config_dir / "waybar"
    waybar_dir.mkdir(parents=True, exist_ok=True)
    (waybar_dir / "colors.css").write_text(css)

    # Also update calendar Pango colors in config.jsonc if present
    cfg_path = waybar_dir / "config.jsonc"
    if cfg_path.exists():
        text = cfg_path.read_text()
        text = re.sub(
            r'("months":\s*"<span color=\')#[0-9A-Fa-f]{6}(\'><b>\{\}</b></span>")',
            rf"\g<1>{p['primary']}\g<2>",
            text,
        )
        text = re.sub(
            r'("days":\s*"<span color=\')#[0-9A-Fa-f]{6}(\'><b>\{\}</b></span>")',
            rf"\g<1>{p['fg']}\g<2>",
            text,
        )
        text = re.sub(
            r'("weeks":\s*"<span color=\')#[0-9A-Fa-f]{6}(\'><b>W\{\}</b></span>")',
            rf"\g<1>{p['secondary']}\g<2>",
            text,
        )
        text = re.sub(
            r'("weekdays":\s*"<span color=\')#[0-9A-Fa-f]{6}(\'><b>\{\}</b></span>")',
            rf"\g<1>{p['primary']}\g<2>",
            text,
        )
        text = re.sub(
            r'("today":\s*"<span color=\')#[0-9A-Fa-f]{6}(\' background=\')#[0-9A-Fa-f]{6}(\'><b>\{\}</b></span>")',
            rf"\g<1>{p['bg']}\g<2>{p['primary']}\g<3>",
            text,
        )
        cfg_path.write_text(text)


def write_kitty(config_dir: Path, p: dict[str, str]) -> None:
    content = f"""# ==============================================================================
# KITTY DYNAMIC THEME (Auto-generated from Wallpaper)
# ==============================================================================
foreground {p["fg"]}
background {p["bg"]}
cursor {p["primary"]}
cursor_text_color {p["bg"]}
selection_foreground {p["bg"]}
selection_background {p["primary"]}

color0 {p["color0"]}
color1 {p["color1"]}
color2 {p["color2"]}
color3 {p["color3"]}
color4 {p["color4"]}
color5 {p["color5"]}
color6 {p["color6"]}
color7 {p["color7"]}
color8 {p["color8"]}
color9 {p["color9"]}
color10 {p["color10"]}
color11 {p["color11"]}
color12 {p["color12"]}
color13 {p["color13"]}
color14 {p["color14"]}
color15 {p["color15"]}

active_tab_foreground {p["bg"]}
active_tab_background {p["primary"]}
inactive_tab_foreground {p["fg_dim"]}
inactive_tab_background {p["bg_alt"]}
tab_bar_background {p["bg"]}
"""
    kitty_dir = config_dir / "kitty"
    kitty_dir.mkdir(parents=True, exist_ok=True)
    (kitty_dir / "current-theme.conf").write_text(content)


def write_yazi(config_dir: Path, p: dict[str, str]) -> None:
    content = f"""# ==============================================================================
# YAZI DYNAMIC THEME (Auto-generated from Wallpaper - Yazi 26.x Schema)
# ==============================================================================

[mgr]
cwd = {{ fg = "{p["primary"]}", bold = true }}

find_keyword  = {{ fg = "{p["warning"]}", bold = true, italic = true, underline = true }}
find_position = {{ fg = "{p["teal"]}", bg = "reset", bold = true, italic = true }}

symlink_target = {{ fg = "{p["teal"]}", italic = true }}

marker_copied   = {{ fg = "{p["mint"]}", bg = "{p["mint"]}" }}
marker_cut      = {{ fg = "{p["error"]}", bg = "{p["error"]}" }}
marker_marked   = {{ fg = "{p["teal"]}", bg = "{p["teal"]}" }}
marker_selected = {{ fg = "{p["primary"]}", bg = "{p["primary"]}" }}
marker_symbol   = "│"

count_copied   = {{ fg = "{p["bg"]}", bg = "{p["mint"]}" }}
count_cut      = {{ fg = "{p["bg"]}", bg = "{p["error"]}" }}
count_selected = {{ fg = "{p["bg"]}", bg = "{p["primary"]}" }}

border_symbol = "│"
border_style  = {{ fg = "{p["border"]}" }}

[tabs]
active    = {{ fg = "{p["bg"]}", bg = "{p["primary"]}", bold = true }}
inactive  = {{ fg = "{p["fg_dim"]}", bg = "{p["bg_highlight"]}" }}
sep_inner = {{ open = "", close = "" }}
sep_outer = {{ open = "", close = "" }}

[mode]
normal_main = {{ fg = "{p["bg"]}", bg = "{p["primary"]}", bold = true }}
normal_alt  = {{ fg = "{p["primary"]}", bg = "{p["bg_highlight"]}" }}

select_main = {{ fg = "{p["bg"]}", bg = "{p["teal"]}", bold = true }}
select_alt  = {{ fg = "{p["teal"]}", bg = "{p["bg_highlight"]}" }}

unset_main  = {{ fg = "{p["bg"]}", bg = "{p["warning"]}", bold = true }}
unset_alt   = {{ fg = "{p["warning"]}", bg = "{p["bg_highlight"]}" }}

[indicator]
parent  = {{ fg = "{p["bg"]}", bg = "{p["secondary"]}", bold = true }}
current = {{ fg = "{p["bg"]}", bg = "{p["primary"]}", bold = true }}
preview = {{ underline = true }}
padding = {{ open = "", close = "" }}

[status]
overall   = {{ bg = "{p["bg_alt"]}" }}
sep_left  = {{ open = "", close = "" }}
sep_right = {{ open = "", close = "" }}

perm_sep   = {{ fg = "{p["fg_dim"]}" }}
perm_type  = {{ fg = "{p["primary"]}" }}
perm_read  = {{ fg = "{p["yellow"]}" }}
perm_write = {{ fg = "{p["error"]}" }}
perm_exec  = {{ fg = "{p["teal"]}" }}

progress_label  = {{ fg = "{p["fg"]}", bold = true }}
progress_normal = {{ fg = "{p["primary"]}", bg = "{p["bg_highlight"]}" }}
progress_error  = {{ fg = "{p["error"]}", bg = "{p["bg_highlight"]}" }}

[which]
border          = {{ fg = "{p["primary"]}" }}
cols            = 3
mask            = {{ bg = "{p["bg_alt"]}" }}
cand            = {{ fg = "{p["primary"]}", bold = true }}
rest            = {{ fg = "{p["fg_dim"]}" }}
desc            = {{ fg = "{p["mint"]}" }}
separator       = "  "
separator_style = {{ fg = "{p["comment"]}" }}

[confirm]
border     = {{ fg = "{p["primary"]}" }}
title      = {{ fg = "{p["primary"]}", bold = true }}
body       = {{ fg = "{p["fg"]}" }}
list       = {{ fg = "{p["fg"]}" }}
btn_yes    = {{ fg = "{p["bg"]}", bg = "{p["primary"]}", bold = true }}
btn_no     = {{ fg = "{p["fg"]}", bg = "{p["bg_highlight"]}" }}
btn_labels = [ "  [Y]es  ", "  (N)o  " ]

[spot]
border   = {{ fg = "{p["primary"]}" }}
title    = {{ fg = "{p["primary"]}", bold = true }}
tbl_col  = {{ fg = "{p["teal"]}" }}
tbl_cell = {{ fg = "{p["bg"]}", bg = "{p["primary"]}", bold = true }}

[notify]
title_info  = {{ fg = "{p["primary"]}" }}
title_warn  = {{ fg = "{p["warning"]}" }}
title_error = {{ fg = "{p["error"]}" }}
icon_info   = ""
icon_warn   = ""
icon_error  = ""

[pick]
border   = {{ fg = "{p["primary"]}" }}
active   = {{ fg = "{p["primary"]}", bold = true }}
inactive = {{ fg = "{p["fg"]}" }}

[input]
border   = {{ fg = "{p["primary"]}" }}
title    = {{ fg = "{p["primary"]}", bold = true }}
value    = {{ fg = "{p["fg"]}" }}
selected = {{ reversed = true }}

[cmp]
border       = {{ fg = "{p["primary"]}" }}
active       = {{ fg = "{p["bg"]}", bg = "{p["primary"]}", bold = true }}
inactive     = {{ fg = "{p["fg"]}" }}
icon_file    = ""
icon_folder  = ""
icon_command = ""

[tasks]
border  = {{ fg = "{p["primary"]}" }}
title   = {{ fg = "{p["primary"]}", bold = true }}
hovered = {{ fg = "{p["primary"]}", bold = true, underline = true }}

[help]
border  = {{ fg = "{p["primary"]}" }}
chord   = {{ fg = "{p["primary"]}", bold = true }}
action  = {{ fg = "{p["fg"]}" }}
hovered = {{ fg = "{p["bg"]}", bg = "{p["primary"]}", bold = true }}

[filetype]
rules = [
    {{ mime = "**/image/*", fg = "{p["teal"]}" }},
    {{ mime = "**/{{audio,video}}/*", fg = "{p["yellow"]}" }},
    {{ mime = "**/application/{{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}}", fg = "{p["warning"]}" }},
    {{ mime = "**/application/{{pdf,doc,rtf}}", fg = "{p["mint"]}" }},
    {{ mime = "vfs/{{absent,stale}}", fg = "{p["fg_dim"]}" }},
    {{ url = "*", is = "orphan", fg = "{p["error"]}" }},
    {{ url = "*", is = "exec", fg = "{p["primary"]}", bold = true }},
    {{ url = "*/", fg = "{p["primary"]}", bold = true }},
    {{ url = "*", fg = "{p["fg"]}" }},
]
"""
    yazi_dir = config_dir / "yazi"
    yazi_dir.mkdir(parents=True, exist_ok=True)
    (yazi_dir / "theme.toml").write_text(content)


def write_nvim(config_dir: Path, p: dict[str, str]) -> None:
    content = f"""-- ==============================================================================
-- NEOVIM DYNAMIC PALETTE (Auto-generated from Wallpaper)
-- ==============================================================================
return {{
  bg            = "{p["bg"]}",
  bg_alt        = "{p["bg_alt"]}",
  bg_highlight  = "{p["bg_highlight"]}",
  bg_visual     = "{p["bg_visual"]}",
  cursor_line   = "{p["cursor_line"]}",
  border        = "{p["border"]}",
  border_glow   = "{p["border_glow"]}",

  fg            = "{p["fg"]}",
  fg_dim        = "{p["fg_dim"]}",
  fg_bright     = "{p["fg_bright"]}",

  neon_green    = "{p["neon_green"]}",
  emerald       = "{p["emerald"]}",
  mint          = "{p["mint"]}",
  lime          = "{p["lime"]}",
  teal          = "{p["teal"]}",
  cyan          = "{p["cyan"]}",
  yellow        = "{p["yellow"]}",
  gold          = "{p["gold"]}",
  error         = "{p["error"]}",
  warning       = "{p["warning"]}",
  comment       = "{p["comment"]}",
}}
"""
    nvim_cfg = config_dir / "nvim" / "lua" / "config"
    nvim_cfg.mkdir(parents=True, exist_ok=True)
    (nvim_cfg / "palette.lua").write_text(content)


def write_fuzzel(config_dir: Path, p: dict[str, str]) -> None:
    bg = p["bg"].lstrip("#").lower()
    fg = p["fg"].lstrip("#").lower()
    prim = p["primary"].lstrip("#").lower()
    sec = p["secondary"].lstrip("#").lower()
    comm = p["comment"].lstrip("#").lower()

    colors_block = f"""[colors]
# Dynamic Wallpaper Palette (RRGGBBAA)
background={bg}f0
text={fg}ff
prompt={prim}ff
placeholder={comm}ff
input={fg}ff
match={prim}ff
selection={sec}cc
selection-text=ffffffff
selection-match={prim}ff
counter={prim}88
border={prim}ff
"""
    fuzzel_dir = config_dir / "fuzzel"
    fuzzel_dir.mkdir(parents=True, exist_ok=True)
    (fuzzel_dir / "colors.ini").write_text(colors_block)

    fuzzel_ini = fuzzel_dir / "fuzzel.ini"
    if fuzzel_ini.exists():
        text = fuzzel_ini.read_text()
        if "[colors]" in text:
            text = text.split("[colors]")[0].rstrip() + "\n\n" + colors_block
            fuzzel_ini.write_text(text)


def write_gtk(config_dir: Path, p: dict[str, str]) -> None:
    gtk_css = f"""@define-color accent_color {p["primary"]};
@define-color accent_fg_color {p["bg"]};
@define-color accent_bg_color {p["primary"]};
@define-color window_bg_color {p["bg"]};
@define-color window_fg_color {p["fg"]};
@define-color headerbar_bg_color {p["bg_alt"]};
@define-color headerbar_fg_color {p["fg"]};
@define-color popover_bg_color {p["bg_alt"]};
@define-color popover_fg_color {p["fg"]};
@define-color view_bg_color {p["bg"]};
@define-color view_fg_color {p["fg"]};
@define-color card_bg_color {p["bg_alt"]};
@define-color card_fg_color {p["fg"]};
@define-color sidebar_bg_color @window_bg_color;
@define-color sidebar_fg_color @window_fg_color;
@define-color sidebar_border_color @window_bg_color;
@define-color sidebar_backdrop_color @window_bg_color;
@define-color theme_selected_bg_color alpha(@accent_color, 0.15);
@define-color theme_selected_fg_color @accent_color;

@import "thunar.css";
"""
    for ver in ("gtk-3.0", "gtk-4.0"):
        gdir = config_dir / ver
        gdir.mkdir(parents=True, exist_ok=True)
        (gdir / "gtk.css").write_text(gtk_css)
        thunar_path = gdir / "thunar.css"
        if thunar_path.exists():
            t_text = thunar_path.read_text()
            t_text = re.sub(r"#6cdd83", "@accent_color", t_text, flags=re.IGNORECASE)
            t_text = re.sub(r"#020503", "@window_bg_color", t_text, flags=re.IGNORECASE)
            t_text = re.sub(r"#050805", "@headerbar_bg_color", t_text, flags=re.IGNORECASE)
            t_text = re.sub(r"#dee4da", "@window_fg_color", t_text, flags=re.IGNORECASE)
            thunar_path.write_text(t_text)


def write_btop_and_cava(config_dir: Path, p: dict[str, str]) -> None:
    # Btop theme
    btop_themes = config_dir / "btop" / "themes"
    btop_themes.mkdir(parents=True, exist_ok=True)
    btop_theme = f"""# Dynamic Wallpaper Theme for btop
theme[main_bg]="{p["bg"]}"
theme[main_fg]="{p["fg"]}"
theme[title]="{p["primary"]}"
theme[hi_fg]="{p["primary"]}"
theme[selected_bg]="{p["bg_visual"]}"
theme[selected_fg]="{p["fg_bright"]}"
theme[inactive_fg]="{p["fg_dim"]}"
theme[proc_misc]="{p["teal"]}"
theme[cpu_box]="{p["border"]}"
theme[mem_box]="{p["border"]}"
theme[net_box]="{p["border"]}"
theme[proc_box]="{p["border"]}"
theme[div_line]="{p["bg_highlight"]}"
theme[temp_start]="{p["mint"]}"
theme[temp_mid]="{p["warning"]}"
theme[temp_end]="{p["error"]}"
theme[cpu_start]="{p["secondary"]}"
theme[cpu_mid]="{p["teal"]}"
theme[cpu_end]="{p["primary"]}"
theme[free_start]="{p["secondary"]}"
theme[free_mid]="{p["mint"]}"
theme[free_end]="{p["primary"]}"
theme[cached_start]="{p["secondary"]}"
theme[cached_mid]="{p["teal"]}"
theme[cached_end]="{p["primary"]}"
theme[available_start]="{p["secondary"]}"
theme[available_mid]="{p["mint"]}"
theme[available_end]="{p["primary"]}"
theme[used_start]="{p["secondary"]}"
theme[used_mid]="{p["teal"]}"
theme[used_end]="{p["primary"]}"
theme[download_start]="{p["secondary"]}"
theme[download_mid]="{p["teal"]}"
theme[download_end]="{p["primary"]}"
theme[upload_start]="{p["secondary"]}"
theme[upload_mid]="{p["mint"]}"
theme[upload_end]="{p["primary"]}"
"""
    (btop_themes / "dynamic.theme").write_text(btop_theme)
    btop_conf = config_dir / "btop" / "btop.conf"
    if btop_conf.exists():
        b_text = btop_conf.read_text()
        b_text = re.sub(r'color_theme\s*=\s*"[^"]*"', 'color_theme = "dynamic"', b_text)
        btop_conf.write_text(b_text)

    # Cava gradient
    cava_conf = config_dir / "cava" / "config"
    if cava_conf.exists():
        c_text = cava_conf.read_text()
        grads = [
            p["secondary"],
            p["border"],
            p["mint"],
            p["primary"],
            p["teal"],
            p["cyan"],
            p["lime"],
            p["yellow"],
        ]
        for idx, col in enumerate(grads, start=1):
            c_text = re.sub(
                rf"gradient_color_{idx}\s*=\s*'#[0-9A-Fa-f]{{6}}'",
                f"gradient_color_{idx} = '{col.lower()}'",
                c_text,
            )
        cava_conf.write_text(c_text)


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: palette_gen.py <path_to_wallpaper>", file=sys.stderr)
        return 1

    wallpaper = os.path.expanduser(sys.argv[1])
    if not os.path.isfile(wallpaper):
        print(f"Error: Wallpaper file not found: {wallpaper}", file=sys.stderr)
        return 1

    config_dir = Path(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")))
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")))
    cache_dir.mkdir(parents=True, exist_ok=True)

    palette = build_palette(wallpaper)
    (cache_dir / "wal_palette.json").write_text(json.dumps(palette, indent=2))

    write_hyprland(config_dir, palette)
    write_waybar(config_dir, palette)
    write_kitty(config_dir, palette)
    write_yazi(config_dir, palette)
    write_nvim(config_dir, palette)
    write_fuzzel(config_dir, palette)
    write_gtk(config_dir, palette)
    write_btop_and_cava(config_dir, palette)

    print(
        f"[palette_gen] Generated dynamic theme from {os.path.basename(wallpaper)} "
        f"(Primary: {palette['primary']}, Secondary: {palette['secondary']}, Hue: {palette['hue']}°)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
