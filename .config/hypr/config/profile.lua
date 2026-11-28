-- Perfil del escritorio ("config"): "mac", "mac-light" o "default". Se elige con
-- Super+Shift+T (Modo Mac / Modo normal) o `~/.config/themes/config-set mac|default`,
-- que lo guarda en ~/.local/state/desktop-profile y hace `hyprctl reload`. Modo Mac
-- guarda "mac-light" si el tema de colores es claro ("light": true en su theme.json),
-- y theme-set cambia entre "mac" y "mac-light" al pasar a un tema claro u oscuro.
--
--   mac        barra macshell (quickshell/macshell) con Spotlight y PowerMenu, ventanas
--              redondeadas con sombra, hyprbars Sur-Gris (gris, Noto Sans, 32 px);
--              todos los workspaces flotantes salvo los que pases a tiling (Super+Alt+D)
--   mac-light  lo mismo en claro (macshell, hyprbars, GTK y Qt claros), con un tema claro
--   default    Modo normal: la barra y el lanzador de Quickshell de siempre, esquinas rectas,
--              hyprbars con el color del tema (28 px); tiling salvo Super+Alt+D
--
-- Sin archivo de estado: "mac" si está macshell, si no "default". Y "mac"/"mac-light"
-- sin macshell instalado se comportan como "default".
-- Lo usan autostart.lua, binds.lua, decorations.lua y desktopmode.lua
--
-- CONTRAST: "Aumentar contraste" (`~/.config/themes/contrast-set on|off|toggle`, que lo
-- guarda en ~/.local/state/increased-contrast como "1" o "0" y hace `hyprctl reload`).
-- decorations.lua lo usa para bordes más gruesos y opacos, y desktopmode.lua
-- para el texto y los botones de hyprbars

local util = require("config.util")
local HOME = util.HOME
local MACSHELL = HOME .. "/.config/quickshell/macshell/shell.qml"
local exists = util.exists

-- Primera palabra de un archivo de ~/.local/state, o nil si no existe
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
