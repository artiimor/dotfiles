local util = require("config.util")
local mainMod = "SUPER"
-- Apps en su propio scope de systemd (app.slice), no dentro de Hyprland. uwsm-app es el
-- cliente rápido de `uwsm app` (sin arrancar Python cada vez); vale también sin uwsm
local launchPrefix = "uwsm-app -- "

-- AZERTY fix: the number-row keys emit symbols (& é " ' ...) without Shift, so
-- binding to the digit characters fails. Bind by physical keycode instead.
-- Digit d -> evdev keycode: 1..9 => 10..18, 0 => 19
local function digitCode(d)
	return "code:" .. (d == 0 and 19 or (9 + d))
end

-- Workspaces independientes por monitor: monitor id 0 -> 1..10, id 1 -> 11..20, ...
-- shortcut: usa el id de Hyprland, que puede cambiar al (des)conectar pantallas; pasar a nombres de salida si molesta
local function wsFor(i)
	local m = hl.get_active_monitor()
	return (m and m.id or 0) * 10 + i
end

-- Ir al workspace trayéndolo a este monitor si vive en otro. Al (des)conectar pantallas
-- los workspaces se quedan donde Hyprland los dejó (p.ej. el 12 en el portátil) y un
-- focus normal saltaba al otro monitor; on_current_monitor lo mueve aquí
local function focusHere(id)
	hl.dispatch(hl.dsp.focus({ workspace = id, on_current_monitor = true }))
end

-- Un bind por tecla numérica (1..9, 0) con los modificadores `mods` (" + SHIFT", "" ...);
-- fn(i) devuelve la acción del workspace i y solo el primero lleva descripción (chuleta)
local function bindDigits(mods, fn, desc)
	for i = 1, NUM_WPM do
		hl.bind(mainMod .. mods .. " + " .. digitCode(i % 10), fn(i), i == 1 and { description = desc } or nil)
	end
end

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("hyprctl kill"), { description = "Kill window (click)" })
hl.bind(mainMod .. " + W", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + D", hl.dsp.window.float({ action = "toggle" }), { description = "Floating / tiling" })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.window.fullscreen({ mode = 1 }), { description = "Maximize" })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.layout("togglesplit"), { description = "Toggle split" })

-- Change focus. Si la ventana que recibe el foco es flotante, sale delante de las demás
-- flotantes (bring_to_top); en tiling no cambia nada
local function focusDir(direction)
	return function()
		hl.dispatch(hl.dsp.focus({ direction = direction }))
		local w = hl.get_active_window()
		if w and w.floating then
			hl.dispatch(hl.dsp.window.bring_to_top())
		end
	end
end
hl.bind(mainMod .. " + H", focusDir("left"), { description = "Focus left" })
hl.bind(mainMod .. " + L", focusDir("right"), { description = "Focus right" })
hl.bind(mainMod .. " + K", focusDir("up"), { description = "Focus up" })
hl.bind(mainMod .. " + J", focusDir("down"), { description = "Focus down" })
-- bring_to_top: en los workspaces de modo escritorio la ventana elegida sale delante
hl.bind("ALT + Tab", function()
	hl.dispatch(hl.dsp.window.cycle_next())
	hl.dispatch(hl.dsp.window.bring_to_top())
end, { description = "Next window" })

-- Move active window around workspaces & monitors
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }), { description = "Move window up" })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }), { description = "Move window right" })
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }), { description = "Move window left" })
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }), { description = "Move window down" })
bindDigits(" + SHIFT", function(i)
	return function()
		-- mover sin seguir y luego ir con focusHere: si el destino vivía en otro monitor,
		-- el workspace (con la ventana) viene a este en vez de llevarte allí
		local id = wsFor(i)
		hl.dispatch(hl.dsp.window.move({ workspace = id, follow = false }))
		focusHere(id)
	end
end, "Move window to workspace")
bindDigits(" + SHIFT + ALT", function(i)
	return function()
		hl.dispatch(hl.dsp.window.move({ workspace = wsFor(i), follow = false }))
	end
end, "Move window to workspace (stay)")

-- Resize active window. Pasos de 50 px; se repite al mantener la tecla
local function resizeBind(key, x, y, desc)
	hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.resize({ x = x, y = y, relative = true }), { repeating = true, description = desc })
end
resizeBind("H", -50, 0, "Narrower window")
resizeBind("J", 0, 50, "Taller window")
resizeBind("K", 0, -50, "Shorter window")
resizeBind("L", 50, 0, "Wider window")

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { description = "Move window with the mouse" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { description = "Resize with the mouse" })

-- Zoom
local function zoom(delta)
	return function()
		local z = hl.get_config("cursor:zoom_factor") + delta
		hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z)) } })
	end
end
hl.bind(mainMod .. " + Minus", zoom(-0.3), { repeating = true, description = "Zoom out" })
hl.bind(mainMod .. " + Plus", zoom(0.3), { repeating = true, description = "Zoom in" })
-- Con el teclado numérico (KP_Subtract / KP_Add)
hl.bind(mainMod .. " + code:82", zoom(-0.3), { repeating = true })
hl.bind(mainMod .. " + code:86", zoom(0.3), { repeating = true })

------------------
---- LAUNCHER ----
------------------

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(launchPrefix .. TERMINAL), { description = "Terminal" })
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER), { description = "Files" })
hl.bind(mainMod .. " + CTRL + T", hl.dsp.exec_cmd(launchPrefix .. EDITOR), { description = "Editor" })
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(launchPrefix .. CALCULATOR), { description = "Calculator" })
hl.bind("XF86Calculator", hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"), { description = "System monitor (btop)" })
-- Copiar / pegar / cortar universal: Ctrl+Insert y Shift+Insert
-- funcionan igual en terminales, navegadores y apps GTK/Qt
hl.bind(mainMod .. " + C", hl.dsp.send_shortcut({ mods = "CTRL", key = "Insert" }), { description = "Copy" })
hl.bind(mainMod .. " + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }), { description = "Paste" })
hl.bind(mainMod .. " + X", hl.dsp.send_shortcut({ mods = "CTRL", key = "X" }), { description = "Cut" })

-- Lanzador y menús de Quickshell (pulsar otra vez cierra)
-- Perfil "mac": Spotlight, energía y notificaciones de macshell (si fallan, los de siempre).
-- Perfil "default": el lanzador, el menú de energía y las notificaciones de Quickshell
local macshell = "qs -p " .. util.MACSHELL_DIR .. " ipc call "
local function shellCmd(mac, own)
	return PROFILE_MAC and (macshell .. mac .. " || " .. own) or own
end
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(shellCmd("spotlight toggle", "qs ipc call launcher apps")), { description = PROFILE_MAC and "Search" or "App launcher" })
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("qs ipc call launcher apps"), { description = "App launcher" })
hl.bind(mainMod .. " + ALT + Space", hl.dsp.exec_cmd("qs ipc call launcher appsFloat"), { description = "App launcher (opens floating)" })
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("qs ipc call launcher clipboard"), { description = "Clipboard" })
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(shellCmd("power toggle", "qs ipc call launcher power")), { description = "Power menu" })
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("qs ipc call launcher emoji"), { description = "Emojis" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("qs ipc call launcher themes"), { description = "Color theme" })
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("qs ipc call launcher configs"), { description = "Config (Mac mode / Normal mode)" })
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd("qs ipc call launcher backgrounds"), { description = "Wallpaper" })
hl.bind(mainMod .. " + CTRL + SHIFT + B", hl.dsp.exec_cmd("~/.config/themes/background-set --next"), { description = "Next wallpaper" })
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("qs ipc call launcher keys"), { description = "Shortcut cheat sheet" })
-- Menú principal, como el de Omarchy (Estilo → tema, fuente, fondo...); en el Modo Mac
-- abre directamente la ventana Appearance de macshell
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(shellCmd("appearance open", "qs ipc call launcher menu")), { description = PROFILE_MAC and "Appearance" or "Menu" })

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio (el OSD lo pone Quickshell solo al ver que cambia el volumen; -l 1 = máximo 100 %)
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call brightness up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call brightness down"), { locked = true, repeating = true })

-------------------
---- UTILITIES ----
-------------------

-- Screen Capture
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m region"), { description = "Screenshot of an area" })
-- Notifications
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(shellCmd("center toggle", "qs ipc call notifs toggle")), { description = "Notifications" })
-- Mostrar / ocultar la barra (como en Omarchy); en el Modo Mac la barra es de macshell
if not PROFILE_MAC then
	hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("qs ipc call bar toggle"), { description = "Show / hide the bar" })
end

-- Lock
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Lock" })
-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Focus on workspace number
bindDigits("", function(i)
	return function()
		focusHere(wsFor(i))
	end
end, "Go to workspace")

-- Workspaces 11..20 (los del monitor externo, p.ej. huérfanos al desconectarlo): solo si existen y tienen ventanas
bindDigits(" + ALT", function(i)
	return function()
		local ws = hl.get_workspace(10 + i)
		if ws and ws.windows > 0 then
			hl.dispatch(hl.dsp.focus({ workspace = 10 + i }))
		end
	end
end, "Go to workspace 11-20")

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "m+1" }), { description = "Switch workspace" })
hl.bind(mainMod .. " + CONTROL + mouse_up", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m+1" }))

-- Cambiar de monitor (los números ya son workspaces del monitor actual)
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ monitor = "+1" }), { description = "Switch monitor" })

-- Mover la ventana activa al workspace activo del otro monitor
-- shortcut: con 3+ monitores elige el primero no enfocado; usar un selector relativo si hace falta
hl.bind(mainMod .. " + SHIFT + Tab", function()
	for _, m in ipairs(hl.get_monitors()) do
		if not m.focused and m.active_workspace then
			hl.dispatch(hl.dsp.window.move({ workspace = m.active_workspace.id }))
			return
		end
	end
end, { description = "Move window to the other monitor" })

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }), { description = "Send to scratchpad" })
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special(), { description = "Scratchpad" })
