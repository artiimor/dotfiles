-- luacheck: only errors (0xx) and undefined or misspelled globals (1xx), no style
only = { "0", "1" }

-- Hyprland: hl API and globals that one config/ file defines and others read
files[".config/hypr"] = {
	std = "lua54",
	globals = {
		"hl", "MONITOR1", "PRIMARY_MONITOR", "NUM_WPM", "UWSM",
		"TERMINAL", "FILE_MANAGER", "EDITOR", "CALCULATOR",
		"PROFILE", "PROFILE_MAC", "PROFILE_LIGHT", "CONTRAST", "DesktopSnap", "DesktopUnsnap",
		"THEME_BORDER", "THEME_INACTIVE", "THEME_GROUP", "THEME_ACCENT", "THEME_BG", "THEME_FG",
	},
}

-- Neovim (LuaJIT); MiniThemeReload is defined by colors/tema.lua for theme-set
local nvim = { std = "luajit", globals = { "vim", "MiniThemeReload" } }
files[".config/nvim"] = nvim
files[".config/nvim-lazyvim"] = nvim
