-- Desktop profile ("config"): "mac", "mac-light" or "default". Chosen with
-- Super+Shift+T (Mac Mode / Normal Mode) or `wasdjy-config mac|default`,
-- which saves it in ~/.local/state/desktop-profile and runs `hyprctl reload`. Mac Mode
-- saves "mac-light" if the color theme is light ("light": true in its theme.json),
-- and wasdjy-theme switches between "mac" and "mac-light" when moving to a light or dark theme.
--
--   mac        macshell bar (quickshell/macshell) with Spotlight and PowerMenu, windows
--              rounded with shadow, Sur-Gris hyprbars (grey, Noto Sans, 32 px);
--              every workspace floating except the ones you switch to tiling (Super+Alt+D)
--   mac-light  the same in light (light macshell, hyprbars, GTK and Qt), with a light theme
--   default    Normal Mode: the usual Quickshell bar and launcher, square corners,
--              hyprbars in the theme color (28 px); tiling except Super+Alt+D
--
-- No state file: "mac" if macshell is present, otherwise "default". And "mac"/"mac-light"
-- without macshell installed behave like "default".
-- Used by autostart.lua, binds.lua, decorations.lua and desktopmode.lua
--
-- CONTRAST: "Increase contrast" (`wasdjy-contrast on|off|toggle`, which
-- saves it in ~/.local/state/increased-contrast as "1" or "0" and runs `hyprctl reload`).
-- decorations.lua uses it for thicker, opaque borders, and desktopmode.lua
-- for the hyprbars text and buttons

local util = require("config.util")
local HOME = util.HOME
local MACSHELL = HOME .. "/.config/quickshell/macshell/shell.qml"
local exists = util.exists

-- First word of a file in ~/.local/state, or nil if it doesn't exist
local function readState(name)
	local f = io.open(HOME .. "/.local/state/" .. name)
	if not f then
		return nil
	end
	local value = (f:read("*l") or ""):match("^%s*(%S+)")
	f:close()
	return value
end

local profile = readState("desktop-profile")
if profile ~= "mac" and profile ~= "mac-light" and profile ~= "default" then
	profile = exists(MACSHELL) and "mac" or "default"
end

PROFILE = profile
PROFILE_MAC = (profile == "mac" or profile == "mac-light") and exists(MACSHELL)
PROFILE_LIGHT = PROFILE_MAC and profile == "mac-light"
CONTRAST = readState("increased-contrast") == "1"
