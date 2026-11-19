-- El colorscheme sale del tema activo (~/.config/themes/current/theme.json, campo
-- "nvim"); si no hay tema, Catppuccin Mocha. Todos con fondo transparente para
-- que se vea el de kitty. Al cambiar de tema, theme-set se lo manda a los Neovim
-- abiertos por su socket (background y colorscheme); los demás, al abrirlos.
local function read_theme()
  local f = io.open(vim.fn.expand("~/.config/themes/current/theme.json"))
  if not f then
    return {}
  end
  local ok, t = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and t or {}
end

local theme = read_theme()

-- Claro u oscuro según el tema ("light": true en theme.json), antes de cargar el
-- colorscheme: rose-pine, gruvbox, everforest y tokyonight eligen variante con esto
vim.o.background = theme.light and "light" or "dark"

local function theme_colorscheme()
  return theme.nvim or "catppuccin"
end

-- Kanagawa: los fondos de flotantes, menús, gutter y statusline salen del tema
-- activo, para que no se queden con el negro de su paleta.
local function kanagawa_ui()
  local u = theme.ui
  if not u then
    return {}
  end
  return {
    fg = u.fg,
    bg_dim = u.bg,
    bg_gutter = "none",
    bg_m3 = u.bg,
    bg_m2 = u.bg,
    bg_m1 = u.launcherBg,
    bg = u.surface,
    bg_p1 = u.launcherSel,
    bg_p2 = u.accentDim,
    pmenu = { bg = u.launcherBg, bg_sel = u.launcherSel, bg_sbar = u.launcherBg, bg_thumb = u.accentDim },
    float = { bg = u.bg, bg_border = u.bg },
  }
end

-- "nvimColors" (opcional en theme.json): pisa colores ui/syn de Kanagawa, p. ej.
-- para subir el contraste de la sintaxis.
local function kanagawa_theme()
  local extra = theme.nvimColors or {}
  return {
    ui = vim.tbl_deep_extend("force", kanagawa_ui(), extra.ui or {}),
    syn = extra.syn,
  }
end

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
    },
  },
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = true,
    },
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    opts = {
      styles = { transparency = true },
    },
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    opts = {
      transparent_mode = true,
    },
  },

  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    opts = {
      transparent = true,
      background = { dark = "dragon" },
      colors = { theme = { all = kanagawa_theme() } },
    },
  },

  {
    "neanias/everforest-nvim",
    main = "everforest",
    lazy = true,
    opts = {
      background = "medium",
      transparent_background_level = 1,
    },
  },

  {
    "Mofiqul/dracula.nvim",
    lazy = true,
    opts = {
      transparent_bg = true,
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = theme_colorscheme(),
    },
  },
}
