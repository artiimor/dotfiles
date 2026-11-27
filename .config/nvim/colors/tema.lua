-- Colorscheme "tema": mini.hues a partir del tema activo (~/.config/themes/current/theme.json).
-- Lo usan los dos Neovim: el chiquito (~/.config/nvim, `nvim`) y LazyVim
-- (~/.config/nvim-lazyvim, `lazyvim`), que lo carga desde aquí con su colors/tema.lua.
-- Sale de ui.bg / ui.fg del tema, pone la sintaxis de nvimColors.syn si existe, pinta la
-- interfaz (números, menús, flotantes, statusline, búsqueda, diagnósticos...) con la paleta
-- del tema (ui, term) en vez de los grises de mini.hues, y deja el fondo transparente
-- para kitty. Al cambiar de tema, theme-set llama a MiniThemeReload() por el socket;
-- además se relee theme.json al recuperar el foco.
-- Necesita mini.hues (de mini.nvim o el plugin suelto nvim-mini/mini.hues).

-- Lectura de theme.json: ../lua/tema/theme.lua relativo a este archivo. Con dofile y no
-- require porque LazyVim también ejecuta este archivo y su runtimepath no incluye
-- ~/.config/nvim/lua.
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local read_theme = dofile(here .. "/../lua/tema/theme.lua").read

-- Clave del tema: cambia si cambia cualquier color que se usa aquí
local function theme_key(t)
  return vim.json.encode({ t.ui or {}, t.term or {}, t.nvimColors or {}, t.light or false })
end

local t = read_theme()
local ui = t.ui or {}
vim.g.tema_key = theme_key(t)

-- Sin colors_name antes de tocar 'background', para que no se vuelva a cargar este archivo
vim.g.colors_name = nil
vim.o.background = t.light and "light" or "dark"
local hues = {
  background = ui.bg or "#141518",
  foreground = ui.fg or "#c8ccd4",
  saturation = "lowmedium", -- sobrio; prueba "medium" si lo ves muy apagado
  accent = "bg",
}
require("mini.hues").setup(hues)

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

-- interfaz: los grises y acentos salen de la paleta del tema, no de mini.hues.
-- nvimColors.ui (opcional) pisa cualquiera de estas claves: panel (menús, flotantes,
-- statusline), sel (fila elegida), cursorline, visual, nontext, whitespace,
-- special, border (por defecto ui.border al 25 %), dim, accent, accent2, muted, red, yellow, ok, info, hint.
-- Lo que falte en el tema sale de la paleta de mini.hues (p).
if t.ui then
  local term = t.term or {}
  local o = (t.nvimColors or {}).ui or {}
  local p = require("mini.hues").make_palette(hues)
  local tbg = (term.background or p.bg):lower()
  -- el primero que se distingue del fondo de la terminal (Normal es transparente)
  local function visible(...)
    for i = 1, select("#", ...) do
      local c = select(i, ...)
      if c and c:lower() ~= tbg then
        return c
      end
    end
  end
  -- mezcla a con b (f = parte de a): borde de flotantes y fondos de diff
  local function blend(a, b, f)
    local function ch(h, i)
      return tonumber(h:sub(i, i + 1), 16)
    end
    local r = {}
    for _, i in ipairs({ 2, 4, 6 }) do
      r[#r + 1] = math.floor(ch(a, i) * f + ch(b, i) * (1 - f) + 0.5)
    end
    return string.format("#%02x%02x%02x", r[1], r[2], r[3])
  end
  local c = {}
  for k, v in pairs({
    fg = p.fg, bg = p.bg, muted = ui.muted or p.fg_mid2, accent = ui.accent or p.blue,
    accent2 = ui.accent2 or p.purple, dim = ui.accentDim or p.bg_mid2, red = ui.red or p.red,
    yellow = ui.yellow or p.yellow, ok = ui.ok or p.green, info = ui.cyan or p.cyan,
    hint = ui.accent2 or p.purple, sel = ui.launcherSel or p.bg_mid,
    panel = visible(ui.launcherBg, ui.bg, ui.surface) or p.bg_edge,
    cursorline = visible(ui.bg, ui.surface, ui.launcherSel) or p.bg_mid,
    visual = term.selection_background or ui.launcherSel or p.bg_mid2,
    nontext = ui.muted or p.fg_mid2, whitespace = ui.accentDim or p.bg_mid2, special = ui.muted or p.fg_mid2,
  }) do
    c[k] = o[k] or v
  end
  -- números de línea: siempre negro en los temas claros y blanco en los oscuros
  c.linenr = t.light and "#000000" or "#ffffff"
  -- borde de los flotantes: ui.border al 25 % sobre el panel, como las islas de Quickshell
  c.border = o.border or (ui.border and blend(ui.border, c.panel, 0.25)) or p.bg_mid2
  local mode = function(bg) return { fg = c.bg, bg = bg, bold = true } end
  local float = { fg = c.fg, bg = c.panel }
  local hl = {
    LineNr = { fg = c.linenr },
    CursorLineNr = { fg = c.accent, bold = true },
    CursorLine = { bg = c.cursorline },
    CursorColumn = { bg = c.cursorline },
    ColorColumn = { bg = c.cursorline },
    QuickFixLine = { bg = c.cursorline, bold = true },
    Visual = { bg = c.visual },
    VisualNOS = { bg = c.visual },
    Cursor = { fg = c.bg, bg = term.cursor or c.accent },
    Search = { fg = c.accent, bg = c.sel },
    IncSearch = { fg = c.bg, bg = c.accent, bold = true },
    CurSearch = { fg = c.bg, bg = c.accent, bold = true },
    Substitute = { fg = c.bg, bg = c.red },
    MatchParen = { fg = c.accent, bg = c.sel, bold = true },
    Pmenu = float,
    PmenuSel = { fg = c.fg, bg = c.sel, bold = true },
    PmenuSbar = { bg = c.panel },
    PmenuThumb = { bg = c.dim },
    PmenuKind = { fg = c.accent2, bg = c.panel },
    PmenuExtra = { fg = c.muted, bg = c.panel },
    PmenuMatch = { fg = c.accent, bg = c.panel, bold = true },
    PmenuMatchSel = { fg = c.accent, bg = c.sel, bold = true },
    WildMenu = { fg = c.fg, bg = c.sel, bold = true },
    NormalFloat = float,
    FloatBorder = { fg = c.border, bg = c.panel },
    FloatTitle = { fg = c.accent, bg = c.panel, bold = true },
    FloatFooter = { fg = c.muted, bg = c.panel },
    StatusLine = { fg = c.fg, bg = c.panel },
    StatusLineNC = { fg = c.muted, bg = c.panel },
    TabLine = { fg = c.muted, bg = c.panel },
    TabLineSel = { fg = c.fg, bg = c.sel, bold = true },
    TabLineFill = { bg = c.panel },
    WinBar = { fg = c.fg, bold = true },
    WinBarNC = { fg = c.muted },
    WinSeparator = { fg = c.dim },
    VertSplit = { fg = c.dim },
    NonText = { fg = c.nontext },
    EndOfBuffer = { fg = c.nontext },
    Whitespace = { fg = c.whitespace },
    SpecialKey = { fg = c.special },
    Conceal = { fg = c.muted },
    Folded = { fg = c.muted, bg = c.panel },
    FoldColumn = { fg = c.nontext },
    SignColumn = {},
    Directory = { fg = c.accent },
    Title = { fg = c.accent, bold = true },
    ErrorMsg = { fg = c.red, bold = true },
    WarningMsg = { fg = c.yellow, bold = true },
    MoreMsg = { fg = c.ok },
    ModeMsg = { fg = c.fg, bold = true },
    Question = { fg = c.accent },
    MsgArea = { fg = c.fg },
    Todo = { fg = c.bg, bg = c.accent, bold = true },
    SpellBad = { sp = c.red, undercurl = true },
    SpellCap = { sp = c.yellow, undercurl = true },
    SpellLocal = { sp = c.info, undercurl = true },
    SpellRare = { sp = c.hint, undercurl = true },
    DiffAdd = { bg = blend(c.ok, c.bg, 0.2) },
    DiffChange = { bg = blend(c.yellow, c.bg, 0.12) },
    DiffDelete = { fg = c.red, bg = blend(c.red, c.bg, 0.2) },
    DiffText = { bg = blend(c.yellow, c.bg, 0.3), bold = true },
    Added = { fg = c.ok },
    Changed = { fg = c.yellow },
    Removed = { fg = c.red },
    -- mini.statusline
    MiniStatuslineModeNormal = mode(c.accent),
    MiniStatuslineModeInsert = mode(c.ok),
    MiniStatuslineModeVisual = mode(c.accent2),
    MiniStatuslineModeReplace = mode(c.red),
    MiniStatuslineModeCommand = mode(c.yellow),
    MiniStatuslineModeOther = mode(c.info),
    MiniStatuslineDevinfo = { fg = c.fg, bg = c.sel },
    MiniStatuslineFileinfo = { fg = c.fg, bg = c.sel },
    MiniStatuslineFilename = { fg = c.muted, bg = c.panel },
    MiniStatuslineInactive = { fg = c.muted, bg = c.panel },
    -- mini.pick
    MiniPickNormal = float,
    MiniPickBorder = { fg = c.border, bg = c.panel },
    MiniPickBorderBusy = { fg = c.yellow, bg = c.panel },
    MiniPickBorderText = { fg = c.accent, bg = c.panel, bold = true },
    MiniPickPrompt = { fg = c.fg, bg = c.panel },
    MiniPickPromptCaret = { fg = c.accent, bg = c.panel },
    MiniPickPromptPrefix = { fg = c.accent, bg = c.panel },
    MiniPickHeader = { fg = c.accent2, bg = c.panel },
    MiniPickMatchCurrent = { bg = c.sel },
    MiniPickMatchMarked = { bg = c.visual },
    MiniPickMatchRanges = { fg = c.accent, bold = true },
    MiniPickPreviewLine = { bg = c.sel },
    MiniPickPreviewRegion = { fg = c.accent, bg = c.sel },
    MiniPickIconDirectory = { fg = c.accent },
    MiniPickIconFile = { fg = c.fg },
    -- el resto de flotantes de mini.* (archivos, avisos, pistas) como los demás
    MiniFilesNormal = float,
    MiniFilesBorder = { fg = c.border, bg = c.panel },
    MiniFilesBorderModified = { fg = c.yellow, bg = c.panel },
    MiniFilesTitle = { fg = c.muted, bg = c.panel },
    MiniFilesTitleFocused = { fg = c.accent, bg = c.panel, bold = true },
    MiniFilesCursorLine = { bg = c.sel },
    MiniFilesDirectory = { fg = c.accent },
    MiniNotifyNormal = float,
    MiniNotifyBorder = { fg = c.border, bg = c.panel },
    MiniNotifyTitle = { fg = c.accent, bg = c.panel, bold = true },
    MiniClueBorder = { fg = c.border, bg = c.panel },
    MiniClueTitle = { fg = c.accent, bg = c.panel, bold = true },
    MiniClueDescGroup = { fg = c.accent2, bg = c.panel },
    MiniClueDescSingle = float,
    MiniClueNextKey = { fg = c.accent, bg = c.panel, bold = true },
    MiniClueNextKeyWithPostkeys = { fg = c.red, bg = c.panel, bold = true },
    MiniClueSeparator = { fg = c.dim, bg = c.panel },
    MiniIndentscopeSymbol = { fg = c.dim },
    MiniTrailspace = { bg = c.red },
    MiniDiffSignAdd = { fg = c.ok },
    MiniDiffSignChange = { fg = c.yellow },
    MiniDiffSignDelete = { fg = c.red },
  }
  -- diagnósticos: texto, subrayado, texto virtual, signo y flotante
  for name, col in pairs({ Error = c.red, Warn = c.yellow, Info = c.info, Hint = c.hint, Ok = c.ok }) do
    hl["Diagnostic" .. name] = { fg = col }
    hl["DiagnosticUnderline" .. name] = { sp = col, undercurl = true }
    hl["DiagnosticVirtualText" .. name] = { fg = col }
    hl["DiagnosticVirtualLines" .. name] = { fg = col }
    hl["DiagnosticSign" .. name] = { fg = col }
    hl["DiagnosticFloating" .. name] = { fg = col, bg = c.panel }
  end
  for g, spec in pairs(hl) do
    vim.api.nvim_set_hl(0, g, spec)
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
