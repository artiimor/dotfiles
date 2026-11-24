-- Utilidades compartidas por varios ficheros de config (se cargan con
-- `local util = require("config.util")`). No van en monitors/variables/inputs
-- porque install.sh no sobrescribe esos.
local M = {}

M.HOME = os.getenv("HOME")
-- Config de macshell (barra del perfil "mac", aparte, no incluida en este repo)
M.MACSHELL_DIR = "~/.config/quickshell/macshell"

-- true si el fichero existe (se puede abrir)
function M.exists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	end
	return false
end

-- Clases de terminal, sin anclas: misc.lua (swallow_regex) la usa entre
-- paréntesis y windowrules.lua con ^( )$
M.TERMINAL_CLASSES = "kitty|ghostty|com\\.mitchellh\\.ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal"

return M
