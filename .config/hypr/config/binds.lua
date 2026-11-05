local mainMod = "SUPER"
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")

-- AZERTY fix: the number-row keys emit symbols (& é " ' ...) without Shift, so
-- binding to the digit characters fails. Bind by physical keycode instead.
-- Digit d -> evdev keycode: 1..9 => 10..18, 0 => 19
local function digitCode(d)
	return "code:" .. (d == 0 and 19 or (9 + d))
end

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + ALT + J", hl.dsp.layout("togglesplit"))

-- Change focus
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
-- bring_to_top: en los workspaces de modo escritorio la ventana elegida sale delante
hl.bind("ALT + Tab", function()
	hl.dispatch(hl.dsp.window.cycle_next())
	hl.dispatch(hl.dsp.window.bring_to_top())
end)

-- Move active window around workspaces & monitors
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
for i = 1, NUM_WPM do
	local key = i % 10
	hl.bind(mainMod .. " + SHIFT + " .. digitCode(key), hl.dsp.window.move({ workspace = i }))
end
for i = 1, NUM_WPM do
	local key = i % 10
	hl.bind(
		mainMod .. " + SHIFT + ALT + " .. digitCode(key),
		hl.dsp.window.move({ workspace = "m~" .. i, follow = false })
	)
end

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Zoom
local function zoomfunction(value)
	local zoomvalue = hl.get_config("cursor:zoom_factor")
	if (zoomvalue + value) > 3.0 then
		hl.config({ cursor = { zoom_factor = 3.0 } })
	elseif (zoomvalue + value) < 1.0 then
		hl.config({ cursor = { zoom_factor = 1.0 } })
	else
		hl.config({ cursor = { zoom_factor = zoomvalue + value } })
	end
end
hl.bind(mainMod .. " + Minus", function()
	zoomfunction(-0.3)
end, { repeating = true })
hl.bind(mainMod .. " + Plus", function()
	zoomfunction(0.3)
end, { repeating = true })

--# Zoom with keypad
hl.bind(mainMod .. " + code:82", function()
	zoomfunction(-0.3)
end, { repeating = true })
hl.bind(mainMod .. " + code:86", function()
	zoomfunction(0.3)
end, { repeating = true })

------------------
---- LAUNCHER ----
------------------

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(launchPrefix .. EDITOR))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind("XF86Calculator", hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))
-- Copiar / pegar / cortar universal: Ctrl+Insert y Shift+Insert
-- funcionan igual en terminales, navegadores y apps GTK/Qt
hl.bind(mainMod .. " + C", hl.dsp.send_shortcut({ mods = "CTRL", key = "Insert" }))
hl.bind(mainMod .. " + V", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Insert" }))
hl.bind(mainMod .. " + X", hl.dsp.send_shortcut({ mods = "CTRL", key = "X" }))

-- Lanzador y menús de Quickshell (pulsar otra vez cierra)
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("qs ipc call launcher apps"))
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("qs ipc call launcher clipboard"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qs ipc call launcher power"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("qs ipc call launcher emoji"))
hl.bind(mainMod .. " + CTRL + T", hl.dsp.exec_cmd("qs ipc call launcher themes"))

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
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m region"))
-- Notifications
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call notifs toggle"))

-- Lock
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("loginctl lock-session"))
-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Focus on monitors
hl.bind(mainMod .. " + " .. digitCode(1), hl.dsp.focus({ monitor = MONITOR1 }))
hl.bind(mainMod .. " + " .. digitCode(2), hl.dsp.focus({ monitor = MONITOR2 }))
hl.bind(mainMod .. " + " .. digitCode(3), hl.dsp.focus({ monitor = MONITOR3 }))

-- Focus on workspace number
for i = 1, NUM_WPM do
	local key = i % 10
	hl.bind(mainMod .. " + " .. digitCode(key), hl.dsp.focus({ workspace = i }))
end

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m+1" }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special())
