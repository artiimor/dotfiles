-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	-- Quickshell (~/.config/quickshell): barra, fondo, notificaciones, OSD,
	-- lanzador, pantalla de bloqueo y polkit. Sustituye a waybar, hyprpaper,
	-- swaync, swayosd-server, wofi, hyprlock y hyprpolkitagent
	hl.exec_cmd("qs & hypridle")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store")
end)
