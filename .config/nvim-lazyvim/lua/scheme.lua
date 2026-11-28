-- Highlight groups shared by our own colorschemes (colors/basalt.lua,
-- colors/miami.lua). Each one only defines its palette and calls apply(name, palette).
-- Transparent background like the other themes (the terminal's shows through).
--
-- Palette: fg bright light grey dim muted faint line surface sel ink
--         red yellow green blue cyan  diff_add diff_change diff_delete diff_text
--         term (16 ANSI colors)
-- Syntax roles (optional, with a default value):
--         keyword func string const type op comment  keyword_bold
local M = {}

function M.apply(name, c)
  vim.cmd("highlight clear")
  vim.g.colors_name = name
  vim.o.background = "dark"

  local r = {
    keyword = c.keyword or c.bright,
    func = c.func or c.light,
    string = c.string or c.green,
    const = c.const or c.yellow,
    type = c.type or c.grey,
    op = c.op or c.dim,
    comment = c.comment or c.muted,
  }
  local bold = c.keyword_bold ~= false
  local none = "NONE"

  local groups = {
    -- Editor
    Normal = { fg = c.fg, bg = none },
    NormalNC = { link = "Normal" },
    NormalFloat = { fg = c.fg, bg = c.surface },
    FloatBorder = { fg = c.faint, bg = c.surface },
    FloatTitle = { fg = c.light, bg = c.surface, bold = true },
    SignColumn = { bg = none },
    LineNr = { fg = c.faint },
    CursorLineNr = { fg = c.grey, bold = true },
    CursorLine = { bg = c.line },
    CursorColumn = { link = "CursorLine" },
    ColorColumn = { bg = c.line },
    Cursor = { fg = c.ink, bg = c.light },
    Visual = { bg = c.sel },
    Search = { fg = c.ink, bg = c.grey },
    IncSearch = { fg = c.ink, bg = c.bright },
    CurSearch = { link = "IncSearch" },
    MatchParen = { fg = c.bright, bold = true, underline = true },
    VertSplit = { fg = c.faint },
    WinSeparator = { fg = c.faint },
    StatusLine = { fg = c.grey, bg = none },
    StatusLineNC = { fg = c.muted, bg = none },
    TabLine = { fg = c.muted, bg = none },
    TabLineSel = { fg = c.bright, bg = none, bold = true },
    TabLineFill = { bg = none },
    Pmenu = { fg = c.fg, bg = c.surface },
    PmenuSel = { fg = c.bright, bg = c.sel, bold = true },
    PmenuSbar = { bg = c.surface },
    PmenuThumb = { bg = c.faint },
    Folded = { fg = c.muted, bg = c.line },
    FoldColumn = { fg = c.faint },
    NonText = { fg = c.faint },
    Whitespace = { fg = c.faint },
    EndOfBuffer = { fg = none },
    Directory = { fg = r.func },
    Title = { fg = c.bright, bold = true },
    ErrorMsg = { fg = c.red },
    WarningMsg = { fg = c.yellow },
    MoreMsg = { fg = c.grey },
    Question = { fg = c.grey },
    ModeMsg = { fg = c.grey },
    WildMenu = { link = "PmenuSel" },
    SpellBad = { sp = c.red, undercurl = true },
    SpellCap = { sp = c.yellow, undercurl = true },

    -- Syntax (treesitter links its @groups to these by default)
    Comment = { fg = r.comment, italic = true },
    Constant = { fg = r.const },
    String = { fg = r.string },
    Character = { link = "String" },
    Number = { link = "Constant" },
    Boolean = { link = "Constant" },
    Float = { link = "Constant" },
    Identifier = { fg = c.fg },
    Function = { fg = r.func },
    Statement = { fg = r.keyword, bold = bold },
    Keyword = { link = "Statement" },
    Conditional = { link = "Statement" },
    Repeat = { link = "Statement" },
    Exception = { link = "Statement" },
    Operator = { fg = r.op },
    PreProc = { fg = r.type },
    Include = { link = "Statement" },
    Type = { fg = r.type },
    Special = { fg = r.op },
    Delimiter = { fg = r.op },
    Tag = { fg = r.keyword },
    Underlined = { underline = true },
    Todo = { fg = c.ink, bg = c.grey, bold = true },
    Error = { fg = c.red },
    ["@variable"] = { fg = c.fg },
    ["@variable.builtin"] = { fg = r.type, italic = true },
    ["@property"] = { fg = c.fg },
    ["@punctuation"] = { fg = r.op },
    ["@tag.attribute"] = { fg = r.type },
    ["@markup.heading"] = { link = "Title" },
    ["@markup.link"] = { fg = c.blue, underline = true },
    ["@markup.raw"] = { link = "String" },

    -- Diagnostics, diff and git
    DiagnosticError = { fg = c.red },
    DiagnosticWarn = { fg = c.yellow },
    DiagnosticInfo = { fg = c.blue },
    DiagnosticHint = { fg = c.cyan },
    DiagnosticOk = { fg = c.green },
    DiagnosticUnderlineError = { sp = c.red, undercurl = true },
    DiagnosticUnderlineWarn = { sp = c.yellow, undercurl = true },
    DiagnosticUnderlineInfo = { sp = c.blue, undercurl = true },
    DiagnosticUnderlineHint = { sp = c.cyan, undercurl = true },
    DiagnosticVirtualTextError = { fg = c.red, italic = true },
    DiagnosticVirtualTextWarn = { fg = c.yellow, italic = true },
    DiagnosticVirtualTextInfo = { fg = c.blue, italic = true },
    DiagnosticVirtualTextHint = { fg = c.cyan, italic = true },
    DiffAdd = { bg = c.diff_add },
    DiffChange = { bg = c.diff_change },
    DiffDelete = { fg = c.red, bg = c.diff_delete },
    DiffText = { bg = c.diff_text },
    Added = { fg = c.green },
    Changed = { fg = c.blue },
    Removed = { fg = c.red },
    GitSignsAdd = { link = "Added" },
    GitSignsChange = { link = "Changed" },
    GitSignsDelete = { link = "Removed" },
    LspReferenceText = { bg = c.sel },
    LspReferenceRead = { bg = c.sel },
    LspReferenceWrite = { bg = c.sel },
    LspInlayHint = { fg = c.muted, italic = true },
  }

  for group, hl in pairs(groups) do
    vim.api.nvim_set_hl(0, group, hl)
  end

  -- Integrated terminal with the theme's terminal palette
  for i, col in ipairs(c.term) do
    vim.g["terminal_color_" .. (i - 1)] = col
  end
end

return M
