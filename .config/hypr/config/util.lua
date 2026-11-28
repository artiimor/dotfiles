-- Utilities shared by several config files (loaded with
-- `local util = require("config.util")`). They don't go in monitors/variables/inputs
-- because install.sh doesn't overwrite those.
local M = {}

M.HOME = os.getenv("HOME")
-- macshell config (the "mac" profile bar, in quickshell/macshell)
M.MACSHELL_DIR = M.HOME .. "/.config/quickshell/macshell"

-- true if the file exists (can be opened)
function M.exists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	end
	return false
end

-- Terminal classes, without anchors: misc.lua (swallow_regex) uses it inside
-- parentheses and windowrules.lua with ^( )$
M.TERMINAL_CLASSES = "kitty|ghostty|com\\.mitchellh\\.ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal"

return M
