-- Colorscheme "tema" (colors/tema.lua): el mismo que el Neovim chiquito, cargado
-- desde ~/.config/nvim/colors/tema.lua (mini.hues a partir de
-- ~/.config/themes/current/theme.json, fondo transparente para kitty). Al cambiar
-- de tema, theme-set llama a MiniThemeReload() por el socket y se recarga solo.
-- Los demás colorschemes siguen instalados para usarlos a mano (:colorscheme ...);
-- el campo "nvim" del tema solo se usa si falta ~/.config/nvim/colors/tema.lua.

-- theme.json con el lector compartido del Neovim chiquito (por ruta absoluta: el
-- runtimepath de LazyVim no incluye ~/.config/nvim/lua); sin él, {} (oscuro, sin ajustes)
local okm, theme_mod = pcall(dofile, vim.fn.expand("~/.config/nvim/lua/tema/theme.lua"))
local theme = okm and theme_mod.read() or {}

-- Claro u oscuro según el tema ("light": true en theme.json), antes de cargar el
-- colorscheme: rose-pine, gruvbox, everforest y tokyonight eligen variante con esto
vim.o.background = theme.light and "light" or "dark"

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
  -- mini.hues suelto (LazyVim no trae mini.nvim entero); lo pide colors/tema.lua
  { "nvim-mini/mini.hues", lazy = true },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true, -- solo es el fallback de colors/tema.lua; lazy.nvim lo carga al pedirlo
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
      colorscheme = "tema",
    },
  },
}
