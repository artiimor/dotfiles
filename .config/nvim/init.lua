-- Sober Neovim with mini.nvim (the default nvim).
-- LazyVim is still available with the `lazyvim` command (NVIM_APPNAME=nvim-lazyvim).
-- Plugins with vim.pack (nvim 0.12): mini.nvim, nvim-lspconfig and nvim-treesitter.
-- LSPs are reused from LazyVim's mason (~/.local/share/nvim-lazyvim/mason/bin)
-- if it exists; otherwise, the system ones.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Plugins ---------------------------------------------------------------------
vim.pack.add({
  "https://github.com/nvim-mini/mini.nvim",
  "https://github.com/neovim/nvim-lspconfig",
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

-- Options: designed for small windows -------------------------------------
local o = vim.o
o.number = true
o.relativenumber = false
o.numberwidth = 2 -- number column as narrow as possible
o.signcolumn = "yes:1" -- a single column for diagnostics/git, fixed so it doesn't jump around
o.laststatus = 3 -- a single global statusline
o.showmode = false -- the statusline already shows the mode
o.cmdheight = 1
o.wrap = false
o.scrolloff = 4
o.sidescrolloff = 4
o.splitright = true
o.splitbelow = true
o.ignorecase = true
o.smartcase = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.undofile = true
o.clipboard = "unnamedplus"
o.mouse = "a"
o.termguicolors = true
o.pumheight = 8
o.updatetime = 300
o.fillchars = "eob: " -- no ~ at the end of the buffer

-- Colors: colors/tema.lua (mini.hues from theme.json) -----------------
-- LazyVim uses the same colorscheme. Transparent background for kitty; when
-- the theme changes with wasdjy-theme it reloads by itself (MiniThemeReload / on focus gain).
vim.cmd.colorscheme("tema")

-- mini.* ------------------------------------------------------------------------
require("mini.icons").setup()
require("mini.icons").mock_nvim_web_devicons()
require("mini.notify").setup({ window = { config = { border = "none" } } })
vim.notify = require("mini.notify").make_notify()
require("mini.statusline").setup({ use_icons = true })
require("mini.extra").setup()
require("mini.pick").setup({ window = { config = function()
  -- centered picker that adapts to the window size
  local h = math.floor(vim.o.lines * 0.6)
  local w = math.floor(vim.o.columns * 0.8)
  return { anchor = "NW", height = h, width = w, row = math.floor((vim.o.lines - h) / 2), col = math.floor((vim.o.columns - w) / 2) }
end } })
require("mini.files").setup({ windows = { preview = false, width_focus = 30 } })
require("mini.completion").setup({ lsp_completion = { source_func = "omnifunc", auto_setup = false } })
require("mini.snippets").setup()
require("mini.pairs").setup()
require("mini.surround").setup()
require("mini.ai").setup()
require("mini.comment").setup()
require("mini.move").setup()
require("mini.diff").setup({ view = { style = "sign" } })
require("mini.git").setup()
require("mini.cursorword").setup()
require("mini.indentscope").setup({ symbol = "│", draw = { animation = require("mini.indentscope").gen_animation.none() } })
require("mini.trailspace").setup()
require("mini.bracketed").setup()
require("mini.sessions").setup()

local clue = require("mini.clue")
clue.setup({
  window = { delay = 300, config = { width = "auto" } },
  triggers = {
    { mode = "n", keys = "<Leader>" }, { mode = "x", keys = "<Leader>" },
    { mode = "n", keys = "g" }, { mode = "x", keys = "g" },
    { mode = "n", keys = "[" }, { mode = "n", keys = "]" },
    { mode = "n", keys = "<C-w>" },
    { mode = "n", keys = "z" }, { mode = "x", keys = "z" },
    { mode = "n", keys = "'" }, { mode = "n", keys = "`" },
    { mode = "n", keys = '"' }, { mode = "i", keys = "<C-r>" },
  },
  clues = {
    { mode = "n", keys = "<Leader>f", desc = "+buscar" },
    { mode = "n", keys = "<Leader>c", desc = "+código" },
    { mode = "n", keys = "<Leader>g", desc = "+git" },
    clue.gen_clues.builtin_completion(), clue.gen_clues.g(), clue.gen_clues.marks(),
    clue.gen_clues.registers(), clue.gen_clues.windows(), clue.gen_clues.z(),
  },
})

-- Treesitter --------------------------------------------------------------------
-- Installed once (needs the tree-sitter CLI, which you already have).
local parsers = { "c", "cpp", "lua", "ruby", "bash", "json", "markdown", "markdown_inline", "vim", "vimdoc", "query", "python", "toml", "yaml" }
require("nvim-treesitter").install(parsers)
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    if pcall(vim.treesitter.start, ev.buf) then
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- LSP ---------------------------------------------------------------------------
-- The same servers LazyVim installed with mason.
local mason_bin = vim.fn.expand("~/.local/share/nvim-lazyvim/mason/bin")
if vim.fn.isdirectory(mason_bin) == 1 then
  vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
end
-- lua_ls: only the Neovim runtime and mini.nvim; indexing the whole runtimepath costs
-- seconds of CPU and hundreds of MB when opening any .lua
local mini_dir = vim.fn.stdpath("data") .. "/site/pack/core/opt/mini.nvim"
vim.lsp.config("lua_ls", {
  settings = { Lua = { workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME, mini_dir } } } },
})
-- clangd only with errors: its normal log goes to stderr and Neovim records it as ERROR
-- in lsp.log, which grows without limit (lowering the vim.lsp.log level doesn't prevent it)
vim.lsp.config("clangd", { cmd = { "clangd", "--log=error" } })
vim.lsp.enable({ "clangd", "ruby_lsp", "lua_ls" })
vim.diagnostic.config({ virtual_text = { spacing = 1, prefix = "●" }, severity_sort = true, float = { border = "rounded" } })
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    vim.bo[ev.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
  end,
})

-- Shortcuts (similar to LazyVim to avoid suffering) -----------------------------------
local map = function(lhs, rhs, desc, mode)
  vim.keymap.set(mode or "n", lhs, rhs, { desc = desc })
end
local pick = require("mini.pick").builtin
local extra = require("mini.extra").pickers

map("<Leader><Space>", pick.files, "Archivos")
map("<Leader>ff", pick.files, "Archivos")
map("<Leader>/", pick.grep_live, "Grep")
map("<Leader>fg", pick.grep_live, "Grep")
map("<Leader>,", pick.buffers, "Buffers")
map("<Leader>fb", pick.buffers, "Buffers")
map("<Leader>fr", extra.oldfiles, "Recientes")
map("<Leader>fh", pick.help, "Ayuda")
map("<Leader>fk", extra.keymaps, "Atajos")
map("<Leader>fd", extra.diagnostic, "Diagnósticos")
map("<Leader>fs", function() extra.lsp({ scope = "document_symbol" }) end, "Símbolos")
-- ␣e opens and closes (toggle). If it's already open, it closes it instead of reopening.
local function files_toggle(use_cwd)
  local mf = require("mini.files")
  if mf.close() then
    return
  end
  local path = vim.api.nvim_buf_get_name(0)
  if use_cwd or path == "" or vim.fn.filereadable(path) == 0 then
    mf.open(vim.uv.cwd(), false)
  else
    mf.open(path, false)
    mf.reveal_cwd()
  end
end
map("<Leader>e", function() files_toggle(false) end, "Explorador (abrir/cerrar)")
map("<Leader>E", function() files_toggle(true) end, "Explorador en cwd")

-- Inside the explorer: opening a file closes it, and Esc / ␣e also close it.
vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesBufferCreate",
  callback = function(ev)
    local mf = require("mini.files")
    local b = ev.data.buf_id
    local open_close = function() mf.go_in({ close_on_file = true }) end
    vim.keymap.set("n", "l", open_close, { buffer = b, desc = "Entrar / abrir y cerrar" })
    vim.keymap.set("n", "<CR>", open_close, { buffer = b, desc = "Entrar / abrir y cerrar" })
    vim.keymap.set("n", "<Right>", open_close, { buffer = b, desc = "Entrar / abrir y cerrar" })
    vim.keymap.set("n", "<Esc>", mf.close, { buffer = b, desc = "Cerrar" })
    vim.keymap.set("n", "<Leader>e", mf.close, { buffer = b, desc = "Cerrar" })
  end,
})

map("gd", vim.lsp.buf.definition, "Ir a definición")
map("gr", function() extra.lsp({ scope = "references" }) end, "Referencias")
map("<Leader>ca", vim.lsp.buf.code_action, "Acción de código", { "n", "x" })
map("<Leader>cr", vim.lsp.buf.rename, "Renombrar")
map("<Leader>cf", function() vim.lsp.buf.format() end, "Formatear")
map("<Leader>cd", vim.diagnostic.open_float, "Diagnóstico de la línea")

map("<Leader>gg", function() vim.cmd("terminal lazygit") vim.cmd("startinsert") end, "lazygit")
map("<Leader>gd", function() require("mini.diff").toggle_overlay(0) end, "Ver cambios (diff)")
map("<Leader>gb", "<Cmd>Git blame -- %<CR>", "Blame")
-- Revert / stage changes (mini.diff: gH = reset, gh = apply, gh is also the hunk textobject)
vim.keymap.set("n", "<Leader>gr", "gHgh", { remap = true, desc = "Revertir cambio (hunk) bajo el cursor" })
vim.keymap.set("x", "<Leader>gr", "gH", { remap = true, desc = "Revertir líneas seleccionadas" })
vim.keymap.set("n", "<Leader>gR", "gHG", { remap = true, desc = "Revertir hasta el final del archivo" })
vim.keymap.set("n", "<Leader>gs", "ghgh", { remap = true, desc = "Stagear cambio bajo el cursor" })
vim.keymap.set("x", "<Leader>gs", "gh", { remap = true, desc = "Stagear líneas seleccionadas" })

map("<S-h>", "<Cmd>bprevious<CR>", "Buffer anterior")
map("<S-l>", "<Cmd>bnext<CR>", "Buffer siguiente")
map("<Leader>bd", function() require("mini.bufremove").delete() end, "Cerrar buffer")
require("mini.bufremove").setup()
map("<C-h>", "<C-w>h", "Ventana izquierda")
map("<C-j>", "<C-w>j", "Ventana abajo")
map("<C-k>", "<C-w>k", "Ventana arriba")
map("<C-l>", "<C-w>l", "Ventana derecha")
map("<Esc>", "<Cmd>nohlsearch<CR>", "Quitar resaltado")
map("<C-s>", "<Cmd>write<CR>", "Guardar", { "n", "i", "x" })
map("<Leader>qq", "<Cmd>qa<CR>", "Salir")

-- Compact mode: in narrow windows no numbers or signcolumn ----------------
local function compact()
  local narrow = vim.o.columns < 70
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      vim.wo[win].number = not narrow
      vim.wo[win].relativenumber = false
      vim.wo[win].signcolumn = narrow and "no" or "yes:1"
    end
  end
end
vim.api.nvim_create_autocmd({ "VimResized", "VimEnter", "BufWinEnter" }, { callback = compact })

-- Simple autosave (like your auto-save.nvim) -----------------------------------
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  callback = function(ev)
    local b = ev.buf
    if vim.bo[b].modified and vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= "" then
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(b) and vim.bo[b].modified then
          vim.api.nvim_buf_call(b, function() vim.cmd("silent! update") end)
        end
      end, 1000)
    end
  end,
})

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", { callback = function() vim.hl.on_yank({ timeout = 150 }) end })

-- User configuration: lua/user.lua (install.sh doesn't overwrite it) ---------------
require("user")
