-- Lectura del tema activo (~/.config/themes/current/theme.json), compartida por los
-- dos Neovim. El chiquito la carga con dofile desde colors/tema.lua; LazyVim
-- (NVIM_APPNAME=nvim-lazyvim, sin ~/.config/nvim/lua en el runtimepath) también la
-- carga con dofile por ruta absoluta. read() siempre devuelve una tabla ({} si falla).
-- TEMA_THEME_JSON (opcional) apunta a otro theme.json: sirve para probar un tema sin
-- cambiar el activo, p. ej. TEMA_THEME_JSON=~/.config/themes/snow/theme.json nvim
-- Con "Aumentar contraste" (contrast-set), theme-set deja el tema con más contraste en
-- ~/.local/state/increased-contrast.json y se lee ese (salvo con TEMA_THEME_JSON).
local M = {}

local contrast = vim.fn.expand("~/.local/state/increased-contrast.json")

local function path()
  if vim.env.TEMA_THEME_JSON then
    return vim.fn.expand(vim.env.TEMA_THEME_JSON)
  end
  return vim.uv.fs_stat(contrast) and contrast or vim.fn.expand("~/.config/themes/current/theme.json")
end

function M.read()
  local f = io.open(path())
  if not f then
    return {}
  end
  local ok, d = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and type(d) == "table" and d or {}
end

return M
