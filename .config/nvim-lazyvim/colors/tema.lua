-- "tema": the same colorscheme as the small Neovim (~/.config/nvim/colors/tema.lua,
-- mini.hues from ~/.config/themes/current/theme.json). A single source: here
-- only that file is loaded. If it's missing (or fails), the theme's "nvim" field is used
-- (read with ~/.config/nvim/lua/tema/theme.lua) or Catppuccin, so LazyVim keeps
-- working on its own.
local shared = vim.fn.expand("~/.config/nvim/colors/tema.lua")
local ok, err = false, "no existe " .. shared
if vim.uv.fs_stat(shared) then
  ok, err = pcall(dofile, shared)
end
if not ok then
  vim.g.colors_name = nil
  local fallback = "catppuccin"
  -- Shared theme.json reader; without ~/.config/nvim, {} (and Catppuccin stays)
  local okm, theme = pcall(dofile, vim.fn.expand("~/.config/nvim/lua/tema/theme.lua"))
  local t = okm and theme.read() or {}
  if type(t.nvim) == "string" and t.nvim ~= "tema" then
    fallback = t.nvim
  end
  -- Outside this file: a :colorscheme nested inside another one does nothing
  -- (Neovim silently ignores it to avoid recursion)
  vim.schedule(function()
    vim.notify("colorscheme tema: " .. tostring(err) .. "; uso " .. fallback, vim.log.levels.WARN)
    if not pcall(vim.cmd.colorscheme, fallback) then
      pcall(vim.cmd.colorscheme, "catppuccin")
    end
  end)
end
