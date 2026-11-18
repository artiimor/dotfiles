-- Perfil del escritorio ("config"): "mac" o "default". Se elige con
-- Super+Shift+T o `~/.config/themes/config-set mac|default`, que lo guarda en
-- ~/.local/state/desktop-profile y hace `hyprctl reload`.
--
--   mac      barra macshell (repo plasma-mac) con Spotlight y PowerMenu, ventanas
--            redondeadas con sombra, hyprbars Sur-Gris (gris, Noto Sans, 32 px)
--   default  la barra y el lanzador de Quickshell de siempre, esquinas rectas,
--            hyprbars con el color del tema (28 px)
--
-- Sin archivo de estado: "mac" si está macshell, si no "default". Y "mac" sin
-- macshell instalado se comporta como "default".
-- Lo usan autostart.lua, binds.lua, decorations.lua y desktopmode.lua

local HOME = os.getenv("HOME")
local MACSHELL = HOME .. "/.config/quickshell/macshell/shell.qml"

local function exists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	end
	return false
end

local profile
local f = io.open(HOME .. "/.local/state/desktop-profile")
if f then
	profile = (f:read("*l") or ""):match("^%s*(%S+)")
	f:close()
end
if profile ~= "mac" and profile ~= "default" then
	profile = exists(MACSHELL) and "mac" or "default"
end

PROFILE = profile
PROFILE_MAC = profile == "mac" and exists(MACSHELL)
