-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

local util = require("config.util")

hl.on("hyprland.start", function()
	-- Con uwsm el entorno de systemd/D-Bus ya lo prepara uwsm (y --all le metería
	-- variables de la sesión que uwsm no quiere ahí); sin uwsm hace falta para los portales
	if not UWSM then
		hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	end
	-- Quickshell (~/.config/quickshell): barra, fondo, notificaciones, OSD,
	-- lanzador, pantalla de bloqueo y polkit. Sustituye a waybar, hyprpaper,
	-- swaync, swayosd-server, wofi, hyprlock y hyprpolkitagent
	hl.exec_cmd("qs & hypridle")
	-- Perfil "mac": barra superior + Spotlight estilo macOS (macshell, en quickshell/macshell).
	-- En "default" la barra la pone el propio qs (shell.qml mira el mismo perfil)
	if PROFILE_MAC then
		hl.exec_cmd("qs -p " .. util.MACSHELL_DIR)
	end
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store")
end)
