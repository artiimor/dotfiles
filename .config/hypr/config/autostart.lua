-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

local util = require("config.util")

hl.on("hyprland.start", function()
	-- With uwsm the systemd/D-Bus environment is already set up by uwsm (and --all would push
	-- session variables uwsm doesn't want there); without uwsm the portals need it
	if not UWSM then
		hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	end
	-- Quickshell (~/.config/quickshell): bar, wallpaper, notifications, OSD,
	-- launcher, lock screen and polkit. Replaces waybar, hyprpaper,
	-- swaync, swayosd-server, wofi, hyprlock and hyprpolkitagent
	hl.exec_cmd("qs & hypridle")
	-- "mac" profile: top bar + macOS-style Spotlight (macshell, in quickshell/macshell).
	-- In "default" the bar comes from qs itself (shell.qml reads the same profile)
	if PROFILE_MAC then
		hl.exec_cmd("qs -p " .. util.MACSHELL_DIR)
	end
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store")
end)
