-- "tema" colorscheme (colors/tema.lua): the same as the small Neovim, loaded
-- from ~/.config/nvim/colors/tema.lua (mini.hues from
-- ~/.config/themes/current/theme.json, transparent background for kitty). When the
-- theme changes, theme-set calls MiniThemeReload() over the socket and it reloads by itself.
-- The other colorschemes are still installed to use by hand (:colorscheme ...);
-- the theme's "nvim" field is only used if ~/.config/nvim/colors/tema.lua is missing.

-- theme.json with the small Neovim's shared reader (by absolute path: the
-- LazyVim runtimepath doesn't include ~/.config/nvim/lua); without it, {} (dark, no tweaks)
local okm, theme_mod = pcall(dofile, vim.fn.expand("~/.config/nvim/lua/tema/theme.lua"))
local theme = okm and theme_mod.read() or {}

-- Light or dark depending on the theme ("light": true in theme.json), before loading the
-- colorscheme: rose-pine, gruvbox, everforest and tokyonight pick their variant with this
vim.o.background = theme.light and "light" or "dark"

-- Kanagawa: the backgrounds of floats, menus, gutter and statusline come from the
-- active theme, so they don't keep their palette's black.
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

-- "nvimColors" (optional in theme.json): overrides Kanagawa ui/syn colors, e.g.
-- to raise the syntax contrast.
local function kanagawa_theme()
  local extra = theme.nvimColors or {}
  return {
    ui = vim.tbl_deep_extend("force", kanagawa_ui(), extra.ui or {}),
    syn = extra.syn,
  }
end

return {
  -- standalone mini.hues (LazyVim doesn't ship the whole mini.nvim); requested by colors/tema.lua
  { "nvim-mini/mini.hues", lazy = true },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true, -- only the fallback of colors/tema.lua; lazy.nvim loads it on request
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
