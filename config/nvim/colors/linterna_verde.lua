-- ==============================================================================
-- LINTERNA VERDE COLOR SCHEME FOR NEOVIM
-- Minimalist emerald, neon green, and dark obsidian aesthetic
-- ==============================================================================

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "linterna_verde"
vim.o.termguicolors = true
vim.o.background = "dark"

local default_palette = {
  bg            = "#050B07",
  bg_alt        = "#0A170F",
  bg_highlight  = "#102619",
  bg_visual     = "#004D28",
  cursor_line   = "#0C1D13",
  border        = "#008F4C",
  border_glow   = "#00FF66",
  
  fg            = "#DEE4DA",
  fg_dim        = "#7A8C7F",
  fg_bright     = "#FFFFFF",
  
  neon_green    = "#00FF66",
  emerald       = "#008F4C",
  mint          = "#96DE85",
  lime          = "#BCF693",
  teal          = "#00FFB2",
  cyan          = "#44DEF5",
  yellow        = "#DBFFC1",
  gold          = "#CEC06B",
  error         = "#FF5555",
  warning       = "#FFAA33",
  comment       = "#536B57",
}

-- Reload dynamic wallpaper palette on every colorscheme invocation
package.loaded["config.palette"] = nil
local ok, dyn_palette = pcall(require, "config.palette")
local c = (ok and type(dyn_palette) == "table") and vim.tbl_extend("force", default_palette, dyn_palette) or default_palette

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- UI Highlights
hl("Normal",        { fg = c.fg, bg = c.bg })
hl("NormalFloat",   { fg = c.fg, bg = c.bg_alt })
hl("FloatBorder",   { fg = c.border_glow, bg = c.bg_alt })
hl("FloatTitle",    { fg = c.neon_green, bg = c.bg_alt, bold = true })
hl("CursorLine",    { bg = c.cursor_line })
hl("CursorLineNr",  { fg = c.neon_green, bold = true })
hl("LineNr",        { fg = c.fg_dim })
hl("LineNrAbove",   { fg = c.fg_dim })
hl("LineNrBelow",   { fg = c.fg_dim })
hl("SignColumn",    { bg = c.bg })
hl("ColorColumn",   { bg = c.bg_alt })
hl("Visual",        { bg = c.bg_visual })
hl("VisualNOS",     { bg = c.bg_visual })
hl("Search",        { fg = c.bg, bg = c.neon_green, bold = true })
hl("IncSearch",     { fg = c.bg, bg = c.teal, bold = true })
hl("CurSearch",     { fg = c.bg, bg = c.teal, bold = true })

-- Windows & Splits
hl("VertSplit",     { fg = c.border, bg = "none" })
hl("WinSeparator",  { fg = c.border, bg = "none" })

-- StatusLine & TabLine
hl("StatusLine",    { fg = c.fg, bg = c.bg_highlight })
hl("StatusLineNC",  { fg = c.fg_dim, bg = c.bg_alt })
hl("TabLine",       { fg = c.fg_dim, bg = c.bg_alt })
hl("TabLineFill",   { bg = c.bg })
hl("TabLineSel",    { fg = c.bg, bg = c.neon_green, bold = true })

-- Popup Menu (Pmenu)
hl("Pmenu",         { fg = c.fg, bg = c.bg_alt })
hl("PmenuSel",      { fg = c.bg, bg = c.neon_green, bold = true })
hl("PmenuSbar",     { bg = c.bg_highlight })
hl("PmenuThumb",    { bg = c.border })

-- Messages
hl("ModeMsg",       { fg = c.neon_green, bold = true })
hl("MoreMsg",       { fg = c.teal, bold = true })
hl("WarningMsg",    { fg = c.warning, bold = true })
hl("ErrorMsg",      { fg = c.error, bold = true })

-- Syntax Highlighting
hl("Comment",       { fg = c.comment, italic = true })
hl("Constant",      { fg = c.lime })
hl("String",        { fg = c.mint })
hl("Character",     { fg = c.mint })
hl("Number",        { fg = c.teal })
hl("Boolean",       { fg = c.neon_green, bold = true })
hl("Float",         { fg = c.teal })

hl("Identifier",    { fg = c.fg })
hl("Function",      { fg = c.neon_green, bold = true })
hl("Statement",     { fg = c.emerald, bold = true })
hl("Conditional",   { fg = c.neon_green })
hl("Repeat",        { fg = c.neon_green })
hl("Label",         { fg = c.teal })
hl("Operator",      { fg = c.mint })
hl("Keyword",       { fg = c.neon_green, bold = true })
hl("Exception",     { fg = c.error })

hl("PreProc",       { fg = c.teal })
hl("Include",       { fg = c.emerald })
hl("Define",        { fg = c.teal })
hl("Macro",         { fg = c.teal })
hl("PreCondit",     { fg = c.teal })

hl("Type",          { fg = c.teal, bold = true })
hl("StorageClass",  { fg = c.emerald })
hl("Structure",     { fg = c.teal })
hl("Typedef",       { fg = c.teal })

hl("Special",       { fg = c.neon_green })
hl("SpecialChar",   { fg = c.mint })
hl("Tag",           { fg = c.teal })
hl("Delimiter",     { fg = c.fg_dim })
hl("SpecialComment",{ fg = c.comment, bold = true, italic = true })
hl("Debug",         { fg = c.warning })

hl("Underlined",    { underline = true })
hl("Ignore",        { fg = c.fg_dim })
hl("Error",         { fg = c.error, bold = true })
hl("Todo",          { fg = c.bg, bg = c.neon_green, bold = true })

-- Diagnostics
hl("DiagnosticError", { fg = c.error })
hl("DiagnosticWarn",  { fg = c.warning })
hl("DiagnosticInfo",  { fg = c.teal })
hl("DiagnosticHint",  { fg = c.mint })
hl("DiagnosticUnderlineError", { undercurl = true, sp = c.error })
hl("DiagnosticUnderlineWarn",  { undercurl = true, sp = c.warning })
hl("DiagnosticUnderlineInfo",  { undercurl = true, sp = c.teal })
hl("DiagnosticUnderlineHint",  { undercurl = true, sp = c.mint })

-- Treesitter Captures
hl("@variable",             { fg = c.fg })
hl("@variable.builtin",     { fg = c.teal })
hl("@variable.parameter",   { fg = c.fg })
hl("@variable.member",      { fg = c.mint })
hl("@constant",             { fg = c.lime })
hl("@constant.builtin",     { fg = c.teal, bold = true })
hl("@module",               { fg = c.teal })
hl("@keyword",              { fg = c.neon_green, bold = true })
hl("@keyword.function",     { fg = c.neon_green, bold = true })
hl("@keyword.return",       { fg = c.neon_green, bold = true })
hl("@string",               { fg = c.mint })
hl("@string.escape",        { fg = c.teal })
hl("@function",             { fg = c.neon_green, bold = true })
hl("@function.builtin",     { fg = c.teal, bold = true })
hl("@function.call",        { fg = c.neon_green })
hl("@function.method",      { fg = c.neon_green })
hl("@constructor",          { fg = c.teal, bold = true })
hl("@type",                 { fg = c.teal, bold = true })
hl("@type.builtin",         { fg = c.teal })
hl("@property",             { fg = c.mint })
hl("@punctuation.bracket",  { fg = c.fg_dim })
hl("@punctuation.delimiter",{ fg = c.fg_dim })
hl("@comment",              { fg = c.comment, italic = true })

-- Git Signs
hl("GitSignsAdd",    { fg = c.neon_green })
hl("GitSignsChange", { fg = c.warning })
hl("GitSignsDelete", { fg = c.error })

-- Telescope
hl("TelescopeBorder",         { fg = c.border_glow, bg = c.bg_alt })
hl("TelescopePromptBorder",   { fg = c.neon_green, bg = c.bg_alt })
hl("TelescopeResultsBorder",  { fg = c.border, bg = c.bg_alt })
hl("TelescopePreviewBorder",  { fg = c.border, bg = c.bg_alt })
hl("TelescopeSelection",      { fg = c.fg_bright, bg = c.bg_visual })
hl("TelescopePromptPrefix",   { fg = c.neon_green })
hl("TelescopeMatching",       { fg = c.neon_green, bold = true })

-- Neo-tree
hl("NeoTreeNormal",           { fg = c.fg, bg = c.bg_alt })
hl("NeoTreeNormalNC",         { fg = c.fg, bg = c.bg_alt })
hl("NeoTreeDirectoryIcon",    { fg = c.neon_green })
hl("NeoTreeDirectoryName",    { fg = c.fg, bold = true })
hl("NeoTreeRootName",         { fg = c.neon_green, bold = true })
hl("NeoTreeFileName",         { fg = c.fg })
hl("NeoTreeGitAdded",         { fg = c.neon_green })
hl("NeoTreeGitModified",      { fg = c.warning })
hl("NeoTreeGitDeleted",       { fg = c.error })
