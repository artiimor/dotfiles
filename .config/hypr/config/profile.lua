-- Perfil del escritorio ("config"): "mac", "mac-light" o "default". Se elige con
-- Super+Shift+T (Modo Mac / Modo normal) o `~/.config/themes/config-set mac|default`,
-- que lo guarda en ~/.local/state/desktop-profile y hace `hyprctl reload`. Modo Mac
-- guarda "mac-light" si el tema de colores es claro ("light": true en su theme.json),
-- y theme-set cambia entre "mac" y "mac-light" al pasar a un tema claro u oscuro.
--
--   mac        barra macshell (config aparte, no incluida) con Spotlight y PowerMenu, ventanas
--              redondeadas con sombra, hyprbars Sur-Gris (gris, Noto Sans, 32 px);
--              todos los workspaces flotantes salvo los que pases a tiling (Super+Alt+D)
--   mac-light  lo mismo en claro (macshell, hyprbars, GTK y Qt claros), con un tema claro
--   default    Modo normal: la barra y el lanzador de Quickshell de siempre, esquinas rectas,
--              hyprbars con el color del tema (28 px); tiling salvo Super+Alt+D
--
-- Sin archivo de estado: "mac" si está macshell, si no "default". Y "mac"/"mac-light"
-- sin macshell instalado se comportan como "default".
-- Lo usan autostart.lua, binds.lua, decorations.lua y desktopmode.lua

local util = require("config.util")
local HOME = util.HOME
local MACSHELL = HOME .. "/.config/quickshell/macshell/shell.qml"
local exists = util.exists

local profile
local f = io.open(HOME .. "/.local/state/desktop-profile")
if f then
	profile = (f:read("*l") or ""):match("^%s*(%S+)")
	f:close()
end
if profile ~= "mac" and profile ~= "mac-light" and profile ~= "default" then
	profile = exists(MACSHELL) and "mac" or "default"
end

PROFILE = profile
PROFILE_MAC = (profile == "mac" or profile == "mac-light") and exists(MACSHELL)
PROFILE_LIGHT = PROFILE_MAC and profile == "mac-light"
