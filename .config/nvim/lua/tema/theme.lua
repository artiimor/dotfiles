-- Lectura del tema activo (~/.config/themes/current/theme.json), compartida por los
-- dos Neovim. El chiquito la carga con dofile desde colors/tema.lua; LazyVim
-- (NVIM_APPNAME=nvim-lazyvim, sin ~/.config/nvim/lua en el runtimepath) también la
-- carga con dofile por ruta absoluta. read() siempre devuelve una tabla ({} si falla).
local M = {}

M.path = vim.fn.expand("~/.config/themes/current/theme.json")

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
