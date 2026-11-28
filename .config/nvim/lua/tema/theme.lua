-- Reads the active theme (~/.config/themes/current/theme.json), shared by both
-- Neovims. The small one loads it with dofile from colors/tema.lua; LazyVim
-- (NVIM_APPNAME=nvim-lazyvim, without ~/.config/nvim/lua in the runtimepath) also
-- loads it with dofile by absolute path. read() always returns a table ({} on failure).
-- TEMA_THEME_JSON (optional) points to another theme.json: useful to test a theme without
-- changing the active one, e.g. TEMA_THEME_JSON=~/.config/themes/snow/theme.json nvim
-- With "Increase contrast" (contrast-set), theme-set leaves the higher-contrast theme in
-- ~/.local/state/increased-contrast.json and that one is read (except with TEMA_THEME_JSON).
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
