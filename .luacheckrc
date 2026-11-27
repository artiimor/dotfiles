-- luacheck: solo errores (0xx) y globales sin definir o mal escritas (1xx), nada de estilo
only = { "0", "1" }

-- Hyprland: API hl y globales que un archivo de config/ define y otros leen
files[".config/hypr"] = {
	std = "lua54",
	globals = {
		"hl", "MONITOR1", "PRIMARY_MONITOR", "NUM_WPM", "UWSM",
		"TERMINAL", "FILE_MANAGER", "EDITOR", "CALCULATOR",
		"PROFILE", "PROFILE_MAC", "PROFILE_LIGHT", "CONTRAST", "DesktopSnap", "DesktopUnsnap",
		"THEME_BORDER", "THEME_INACTIVE", "THEME_GROUP", "THEME_ACCENT", "THEME_BG", "THEME_FG",
	},
}

-- Neovim (LuaJIT); MiniThemeReload la define colors/tema.lua para theme-set
local nvim = { std = "luajit", globals = { "vim", "MiniThemeReload" } }
files[".config/nvim"] = nvim
files[".config/nvim-lazyvim"] = nvim
