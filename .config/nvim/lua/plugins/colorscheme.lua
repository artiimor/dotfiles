-- El colorscheme sale del tema activo (~/.config/themes/current/theme.json, campo
-- "nvim"); si no hay tema, Catppuccin Mocha. Todos con fondo transparente para
-- que se vea el de kitty. Al cambiar de tema se aplica al abrir Neovim de nuevo.
local function theme_colorscheme()
  local f = io.open(vim.fn.expand("~/.config/themes/current/theme.json"))
  if not f then
    return "catppuccin"
  end
  local ok, t = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and t.nvim or "catppuccin"
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
    "LazyVim/LazyVim",
    opts = {
      colorscheme = theme_colorscheme(),
    },
  },
}
