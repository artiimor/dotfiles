-- Lectura del tema activo (~/.config/themes/current/theme.json), compartida por los
-- dos Neovim. El chiquito la carga con dofile desde colors/tema.lua; LazyVim
-- (NVIM_APPNAME=nvim-lazyvim, sin ~/.config/nvim/lua en el runtimepath) también la
-- carga con dofile por ruta absoluta. read() siempre devuelve una tabla ({} si falla).
-- TEMA_THEME_JSON (opcional) apunta a otro theme.json: sirve para probar un tema sin
-- cambiar el activo, p. ej. TEMA_THEME_JSON=~/.config/themes/snow/theme.json nvim
local M = {}

M.path = vim.fn.expand(vim.env.TEMA_THEME_JSON or "~/.config/themes/current/theme.json")

function M.read()
  local f = io.open(M.path)
  if not f then
    return {}
  end
  local ok, d = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and type(d) == "table" and d or {}
end

return M
