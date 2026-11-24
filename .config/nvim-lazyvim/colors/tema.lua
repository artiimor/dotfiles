-- "tema": el mismo colorscheme que el Neovim chiquito (~/.config/nvim/colors/tema.lua,
-- mini.hues a partir de ~/.config/themes/current/theme.json). Una sola fuente: aquí
-- solo se carga ese archivo. Si no está (o falla), se usa el campo "nvim" del tema
-- (leído con ~/.config/nvim/lua/tema/theme.lua) o Catppuccin, para que LazyVim siga
-- funcionando por su cuenta.
local shared = vim.fn.expand("~/.config/nvim/colors/tema.lua")
local ok, err = false, "no existe " .. shared
if vim.uv.fs_stat(shared) then
  ok, err = pcall(dofile, shared)
end
if not ok then
  vim.g.colors_name = nil
  local fallback = "catppuccin"
  -- Lector compartido de theme.json; sin ~/.config/nvim, {} (y queda Catppuccin)
  local okm, theme = pcall(dofile, vim.fn.expand("~/.config/nvim/lua/tema/theme.lua"))
  local t = okm and theme.read() or {}
  if type(t.nvim) == "string" and t.nvim ~= "tema" then
    fallback = t.nvim
  end
  -- Fuera de este archivo: un :colorscheme anidado dentro de otro no hace nada
  -- (Neovim lo ignora en silencio para evitar recursión)
  vim.schedule(function()
    vim.notify("colorscheme tema: " .. tostring(err) .. "; uso " .. fallback, vim.log.levels.WARN)
    if not pcall(vim.cmd.colorscheme, fallback) then
      pcall(vim.cmd.colorscheme, "catppuccin")
    end
  end)
end
