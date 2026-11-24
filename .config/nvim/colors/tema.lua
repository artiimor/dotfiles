-- Colorscheme "tema": mini.hues a partir del tema activo (~/.config/themes/current/theme.json).
-- Lo usan los dos Neovim: el chiquito (~/.config/nvim, `nvim`) y LazyVim
-- (~/.config/nvim-lazyvim, `lazyvim`), que lo carga desde aquí con su colors/tema.lua.
-- Sale de ui.bg / ui.fg del tema, pone la sintaxis de nvimColors.syn si existe y deja
-- el fondo transparente para kitty. Al cambiar de tema, theme-set llama a
-- MiniThemeReload() por el socket; además se relee theme.json al recuperar el foco.
-- Necesita mini.hues (de mini.nvim o el plugin suelto nvim-mini/mini.hues).

-- Lectura de theme.json: ../lua/tema/theme.lua relativo a este archivo. Con dofile y no
-- require porque LazyVim también ejecuta este archivo y su runtimepath no incluye
-- ~/.config/nvim/lua.
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local read_theme = dofile(here .. "/../lua/tema/theme.lua").read

local function theme_key(t)
  local ui = t.ui or {}
  return (ui.bg or "") .. (ui.fg or "") .. tostring(t.light) .. vim.json.encode((t.nvimColors or {}).syn or {})
end

local t = read_theme()
local ui = t.ui or {}
vim.g.tema_key = theme_key(t)

-- Sin colors_name antes de tocar 'background', para que no se vuelva a cargar este archivo
vim.g.colors_name = nil
vim.o.background = t.light and "light" or "dark"
require("mini.hues").setup({
  background = ui.bg or "#141518",
  foreground = ui.fg or "#c8ccd4",
  saturation = "lowmedium", -- sobrio; prueba "medium" si lo ves muy apagado
  accent = "bg",
})

-- transparencia: que se vea el fondo de kitty
for _, g in ipairs({ "Normal", "NormalNC", "SignColumn", "LineNr", "EndOfBuffer", "FoldColumn" }) do
  vim.api.nvim_set_hl(0, g, vim.tbl_extend("force", vim.api.nvim_get_hl(0, { name = g }), { bg = "NONE" }))
end

-- sintaxis: usa nvimColors.syn del tema si existe (mini.hues sola queda casi gris)
local syn = (t.nvimColors or {}).syn or {}
local groups = {
  string = { "String", "@string" },
  number = { "Number", "Float", "@number", "@number.float" },
  constant = { "Constant", "Boolean", "@constant", "@constant.builtin", "@boolean" },
  identifier = { "Identifier", "@variable.member" },
  parameter = { "@variable.parameter" },
  fun = { "Function", "@function", "@function.call", "@function.method", "@function.method.call", "@function.builtin" },
  statement = { "Statement", "Conditional", "Repeat", "Exception" },
  keyword = { "Keyword", "@keyword", "@keyword.function", "@keyword.return", "@keyword.conditional", "@keyword.repeat", "@keyword.exception" },
  operator = { "Operator", "@operator" },
  preproc = { "PreProc", "Include", "@keyword.import" },
  type = { "Type", "@type", "@type.builtin", "@module" },
  regex = { "@string.regexp" },
  punct = { "Delimiter", "@punctuation.delimiter", "@punctuation.bracket" },
  comment = { "Comment", "@comment" },
  special1 = { "Special", "@string.special.symbol", "@variable.builtin" },
  special2 = { "SpecialChar", "@string.escape" },
  special3 = { "@punctuation.special" },
}
for key, names in pairs(groups) do
  if syn[key] then
    for _, g in ipairs(names) do
      vim.api.nvim_set_hl(0, g, { fg = syn[key], italic = key == "comment" or nil })
    end
  end
end

vim.g.colors_name = "tema"

-- Recarga: al recuperar el foco solo si el tema ha cambiado y seguimos con "tema"
vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("tema_colorscheme", { clear = true }),
  callback = function()
    if vim.g.colors_name == "tema" and theme_key(read_theme()) ~= vim.g.tema_key then
      vim.cmd.colorscheme("tema")
    end
  end,
})
-- theme-set llama a MiniThemeReload() por el socket en vez de :colorscheme
_G.MiniThemeReload = function()
  vim.cmd.colorscheme("tema")
  vim.cmd.redraw({ bang = true })
end
-- (solo la primera vez: no se puede redefinir mientras se está ejecutando)
if vim.fn.exists("*MiniThemeReload") == 0 then
  vim.cmd([[
function MiniThemeReload() abort
  lua MiniThemeReload()
  return ''
endfunction
]])
end
