-- ==============================================================================
-- HYPRLAND 0.56+ LUA CONFIGURATION - DYNAMIC WALLPAPER THEME (TERMINAL-FIRST)
-- ==============================================================================

local home     = os.getenv("HOME") or "/home/batman"
local hypr_dir = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/hypr"
package.path   = package.path .. ";" .. hypr_dir .. "/?.lua"

-- Reload dynamic colors generated from the current wallpaper on every reload
package.loaded["colors"] = nil
local ok, colors = pcall(require, "colors")
if not ok or type(colors) ~= "table" then
    colors = {
        primary         = "19FF76",
        secondary       = "139960",
        active_border_1 = "rgba(19FF76ee)",
        active_border_2 = "rgba(139960ee)",
        inactive_border = "rgba(0F2819aa)",
        shadow_active   = "rgba(19ff7633)",
        shadow_inactive = "rgba(00000066)",
    }
end

-- --- Monitores (Auto-adaptable a cualquier resolución y tasa de refresco) ---
-- Detecta automáticamente la resolución nativa, posición y máximo refresco (60Hz, 120Hz, 144Hz, 240Hz, 4K, 2K, Ultrawide)
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- --- Programas Predeterminados (Terminal-First) ---
local terminal    = "kitty"
local fileManager = "kitty -e yazi"
local menu        = "fuzzel"
local browser     = "chromium"
local editor      = "kitty -e nvim"

-- --- Autostart (Inicio Automático) ---
hl.on("hyprland.start", function()
    -- Fondo de pantalla y tema dinámico (restaura el último wallpaper o usa mi_wallpaper.png)
    hl.exec_cmd(hypr_dir .. "/scripts/theme-switch.sh --init")

    -- Barra de estado Waybar
    hl.exec_cmd("waybar")

    -- Autenticación Polkit
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Portapapeles (cliphist)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Cursor Green Lantern
    hl.exec_cmd("hyprctl setcursor GL-Kyle-Rayner 24")
end)

-- --- Variables de Entorno (Compatibilidad Wayland + HiDPI Dinámico) ---
hl.env("XCURSOR_THEME", "GL-Kyle-Rayner")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "GL-Kyle-Rayner")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_ENABLE_HIGHDPI_SCALING", "1")
hl.env("GDK_SCALE", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")

-- --- Entrada, Apariencia General, Decoración, Layout y Misc ---
hl.config({
    input = {
        kb_layout    = "us,latam",
        kb_options   = "grp:alt_shift_toggle",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
            scroll_factor        = 0.3,
        },
    },

    general = {
        gaps_in          = 5,
        gaps_out         = 10,
        border_size      = 2,

        col = {
            active_border   = { colors = { colors.active_border_1, colors.active_border_2 }, angle = 45 },
            inactive_border = colors.inactive_border,
        },

        layout           = "dwindle",
        resize_on_border = true,
        allow_tearing    = false,
    },

    decoration = {
        rounding         = 0,
        active_opacity   = 0.98,
        inactive_opacity = 0.90,

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            new_optimizations = true,
            xray              = false,
        },

        shadow = {
            enabled        = true,
            range          = 15,
            render_power   = 3,
            color          = colors.shadow_active,
            color_inactive = colors.shadow_inactive,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        vrr                      = 0,
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

-- --- Curvas y Animaciones Suaves ---
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },   { 0.32, 1 }   } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0 },   { 0.35, 1 }   } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },      { 1, 1 }      } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },  { 0.75, 1.0 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },   { 0.1, 1 }    } })

hl.animation({ leaf = "windows",     enabled = true, speed = 4.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4,   bezier = "easeOutQuint",   style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3.5, bezier = "easeInOutCubic", style = "popin 85%" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 2.5, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 2.5, bezier = "almostLinear" })
hl.animation({ leaf = "fade",        enabled = true, speed = 4,   bezier = "quick" })
hl.animation({ leaf = "layers",      enabled = true, speed = 4,   bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 4,   bezier = "easeOutQuint",   style = "fade" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 3,   bezier = "linear",         style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4,   bezier = "easeOutQuint",   style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 6,   bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 25,  bezier = "linear",         style = "loop" })

-- ==============================================================================
-- WINDOW RULES (Reglas de Ventanas y Flotantes)
-- ==============================================================================
-- Suprimir peticiones automáticas de maximizado
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Terminal Kitty estándar: siempre en mosaico tileado respetando gaps
hl.window_rule({
    name       = "kitty-tiled",
    match      = { class = "^kitty$" },
    fullscreen = false,
})

-- Kitty Flotante Especial (SUPER + SHIFT + ENTER / SUPER + ALT + ENTER)
hl.window_rule({
    name   = "kitty-floating",
    match  = { class = "^kitty-floating$" },
    float  = true,
    size   = "(monitor_w*0.7) (monitor_h*0.65)",
    center = true,
})

-- Monitor de Sistema Btop Flotante (SUPER + ESC)
hl.window_rule({
    name   = "btop-floating",
    match  = { class = "^btop-floating$" },
    float  = true,
    size   = "(monitor_w*0.75) (monitor_h*0.75)",
    center = true,
})

-- Diálogos y controles de audio flotantes
hl.window_rule({
    name   = "audio-dialogs",
    match  = { class = "pavucontrol|pwvucontrol|blueman-manager" },
    float  = true,
    center = true,
})

-- ==============================================================================
-- KEYBINDINGS - MAPEO FIEL DE CAELESTIA + TEMA DINÁMICO
-- ==============================================================================
local mainMod = "SUPER"
local repeating        = { repeating = true }
local locked           = { locked = true }
local locked_repeating = { locked = true, repeating = true }
local mouse            = { mouse = true }

-- --- Aplicaciones Principales ---
hl.bind(mainMod .. " + RETURN",         hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + T",              hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("kitty --class kitty-floating"))
hl.bind(mainMod .. " + ALT + RETURN",   hl.dsp.exec_cmd("kitty --class kitty-floating"))
hl.bind(mainMod .. " + Escape",         hl.dsp.exec_cmd("kitty --class btop-floating -e btop"))
hl.bind(mainMod .. " + E",              hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W",              hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + C",              hl.dsp.exec_cmd(editor))
hl.bind("CTRL + ALT + V",               hl.dsp.exec_cmd("pwvucontrol || pavucontrol"))

-- --- Cambio de Idioma del Teclado (US <-> LATAM / ES con notificación en pantalla) ---
hl.bind("SHIFT + RETURN", hl.dsp.exec_cmd(hypr_dir .. "/scripts/switch-kb.sh"))

-- --- Lanzador, Portapapeles y Tema Dinámico (Wallpaper) ---
hl.bind(mainMod .. " + SPACE",     hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + V",         hl.dsp.exec_cmd(hypr_dir .. "/scripts/clipmenu.sh"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(hypr_dir .. "/scripts/theme-switch.sh --select"))
hl.bind(mainMod .. " + ALT + W",   hl.dsp.exec_cmd(hypr_dir .. "/scripts/theme-switch.sh --random"))

-- --- Gestión de Ventanas (Acciones de Caelestia) ---
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + ALT + F",     hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.window.float())
hl.bind(mainMod .. " + P",           hl.dsp.window.pin())

-- Redimensionado fino de ventanas con teclado
hl.bind(mainMod .. " + MINUS",         hl.dsp.window.resize({ x = -20, y = 0, relative = true }), repeating)
hl.bind(mainMod .. " + EQUAL",         hl.dsp.window.resize({ x = 20,  y = 0, relative = true }), repeating)
hl.bind(mainMod .. " + SHIFT + MINUS", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), repeating)
hl.bind(mainMod .. " + SHIFT + EQUAL", hl.dsp.window.resize({ x = 0, y = 20,  relative = true }), repeating)

-- Alternar foco entre ventanas (Alt+Tab)
hl.bind("ALT + TAB",         hl.dsp.window.cycle_next())
hl.bind("SHIFT + ALT + TAB", hl.dsp.window.cycle_next({ next = false }))

-- Grupos de Ventanas (Caelestia Window Groups)
hl.bind(mainMod .. " + COMMA",         hl.dsp.group.toggle())
hl.bind(mainMod .. " + SHIFT + COMMA", hl.dsp.group.lock_active())
hl.bind(mainMod .. " + U",             hl.dsp.group.next())

-- Movimiento de ventanas y redimensión con ratón
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   mouse)
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), mouse)

-- --- Movimiento de Foco Direccional (Flechas y Vim) ---
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Mover ventanas de posición
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- --- Espacios de Trabajo (Workspaces 1 - 10) ---
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + ALT + " .. key,   hl.dsp.window.move({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Navegación con rueda del ratón y teclas RePág / AvPág
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "-1" }))
hl.bind(mainMod .. " + Page_Down",  hl.dsp.focus({ workspace = "+1" }))
hl.bind(mainMod .. " + Page_Up",    hl.dsp.focus({ workspace = "-1" }))

-- Espacio de Trabajo Especial (Caelestia Special Ws)
hl.bind(mainMod .. " + S",       hl.dsp.workspace.toggle_special("special"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:special" }))

-- --- Control de Audio y Brillo (Teclas Multimedia) ---
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),    locked_repeating)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),    locked_repeating)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   locked_repeating)
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked_repeating)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"),                        locked_repeating)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),                        locked_repeating)

-- --- Control Multimedia (MPRIS) ---
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       locked)
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   locked)

-- --- Capturas de Pantalla ---
hl.bind("Print",                   hl.dsp.exec_cmd([[mkdir -p ~/Pictures/Screenshots && grim -g "$(slurp)" ~/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png]]))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))

-- --- Sesión y Recarga ---
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind("CTRL + ALT + Delete",     hl.dsp.exit())
