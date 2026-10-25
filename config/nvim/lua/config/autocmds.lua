-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Live Dynamic Wallpaper Theme Reload via SIGUSR1 (triggered by theme-switch.sh)
vim.api.nvim_create_autocmd("Signal", {
  pattern = "SIGUSR1",
  group = vim.api.nvim_create_augroup("DynamicWallpaperThemeReload", { clear = true }),
  callback = function()
    vim.schedule(function()
      package.loaded["config.palette"] = nil
      pcall(vim.cmd.colorscheme, "linterna_verde")
    end)
  end,
})
