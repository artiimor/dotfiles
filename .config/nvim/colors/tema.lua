-- "tema" colorscheme: mini.hues from the active theme (~/.config/themes/current/theme.json).
-- Used by both Neovims: the small one (~/.config/nvim, `nvim`) and LazyVim
-- (~/.config/nvim-lazyvim, `lazyvim`), which loads it from here with its colors/tema.lua.
-- Built from the theme's ui.bg / ui.fg, applies the nvimColors.syn syntax if present, paints the
-- UI (numbers, menus, floats, statusline, search, diagnostics...) with the theme's
-- palette (ui, term) instead of mini.hues' greys, and leaves the background transparent
-- for kitty. When the theme changes, theme-set calls MiniThemeReload() over the socket;
-- theme.json is also re-read on focus gain.
-- Requires mini.hues (from mini.nvim or the standalone nvim-mini/mini.hues plugin).

-- Reading theme.json: ../lua/tema/theme.lua relative to this file. dofile and not
-- require because LazyVim also runs this file and its runtimepath doesn't include
-- ~/.config/nvim/lua.
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local read_theme = dofile(here .. "/../lua/tema/theme.lua").read

-- Theme key: changes if any color used here changes
local function theme_key(t)
  return vim.json.encode({ t.ui or {}, t.term or {}, t.nvimColors or {}, t.light or false })
end

local t = read_theme()
local ui = t.ui or {}
vim.g.tema_key = theme_key(t)

-- No colors_name before touching 'background', so this file isn't loaded again
vim.g.colors_name = nil
vim.o.background = t.light and "light" or "dark"
local hues = {
  background = ui.bg or "#141518",
  foreground = ui.fg or "#c8ccd4",
  saturation = "lowmedium", -- sober; try "medium" if it looks too dull
  accent = "bg",
}
require("mini.hues").setup(hues)

-- transparency: let kitty's background show through
for _, g in ipairs({ "Normal", "NormalNC", "SignColumn", "LineNr", "EndOfBuffer", "FoldColumn" }) do
  vim.api.nvim_set_hl(0, g, vim.tbl_extend("force", vim.api.nvim_get_hl(0, { name = g }), { bg = "NONE" }))
end

-- syntax: uses the theme's nvimColors.syn if present (mini.hues alone is almost grey)
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

-- UI: greys and accents come from the theme palette, not from mini.hues.
-- nvimColors.ui (optional) overrides any of these keys: panel (menus, floats,
-- statusline), sel (selected row), cursorline, visual, nontext, whitespace,
-- special, border (ui.border at 25 % by default), dim, accent, accent2, muted, red, yellow, ok, info, hint.
-- Whatever the theme lacks comes from the mini.hues palette (p).
if t.ui then
  local term = t.term or {}
  local o = (t.nvimColors or {}).ui or {}
  local p = require("mini.hues").make_palette(hues)
  local tbg = (term.background or p.bg):lower()
  -- the first one that stands out from the terminal background (Normal is transparent)
  local function visible(...)
    for i = 1, select("#", ...) do
      local c = select(i, ...)
      if c and c:lower() ~= tbg then
        return c
      end
    end
  end
  -- blends a with b (f = share of a): float border and diff backgrounds
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
  -- line numbers: always black in light themes and white in dark ones
  c.linenr = t.light and "#000000" or "#ffffff"
  -- float border: ui.border at 25 % over the panel, like the Quickshell islands
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
    -- the rest of the mini.* floats (files, notifications, clues) like the others
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
  -- diagnostics: text, underline, virtual text, sign and float
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

-- Reload: on focus gain only if the theme changed and we're still on "tema"
vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("tema_colorscheme", { clear = true }),
  callback = function()
    if vim.g.colors_name == "tema" and theme_key(read_theme()) ~= vim.g.tema_key then
      vim.cmd.colorscheme("tema")
    end
  end,
})
-- theme-set calls MiniThemeReload() over the socket instead of :colorscheme
_G.MiniThemeReload = function()
  vim.cmd.colorscheme("tema")
  vim.cmd.redraw({ bang = true })
end
-- (only the first time: it can't be redefined while it's running)
if vim.fn.exists("*MiniThemeReload") == 0 then
  vim.cmd([[
function MiniThemeReload() abort
  lua MiniThemeReload()
  return ''
endfunction
]])
end
