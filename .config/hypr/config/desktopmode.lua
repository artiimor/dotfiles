-- Modo escritorio por workspace: las ventanas flotan,
-- se pueden minimizar y Quickshell enseña un dock abajo.
--   Super+Alt+D   activar/desactivar en el workspace actual
--   Super+M       minimizar (va a special:minimized; se recupera desde el dock)
-- La lista de workspaces se guarda en un archivo: así sobrevive a recargas y
-- Quickshell lo lee para saber dónde poner el dock.
local stateFile = os.getenv("HOME") .. "/.local/state/desktop-workspaces"

local desktop = {}
local f = io.open(stateFile)
if f then
	for name in f:lines() do
		desktop[name] = true
	end
	f:close()
end

local function save()
	local out = io.open(stateFile, "w")
	if not out then
		return
	end
	for name in pairs(desktop) do
		out:write(name, "\n")
	end
	out:close()
end

-- Tamaño de las ventanas nuevas: fracción de la pantalla (en píxeles lógicos,
-- por eso se divide por la escala)
local OPEN_SIZE = 0.65

-- La etiqueta "desktop" marca las ventanas que hemos hecho flotar nosotros, para
-- no devolver al tiling las que flotan por una window rule (Dolphin, calculadora...)
local function makeFloat(w, center)
	if w.floating then
		return
	end
	hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
	hl.dispatch(hl.dsp.window.tag({ tag = "+desktop", window = w }))
	if center then
		local m = w.monitor
		if m then
			hl.dispatch(hl.dsp.window.resize({
				x = math.floor(m.width / m.scale * OPEN_SIZE),
				y = math.floor(m.height / m.scale * OPEN_SIZE),
				window = w,
			}))
		end
		hl.dispatch(hl.dsp.window.center({ window = w }))
	end
end

local function makeTiled(w)
	local tags = type(w.tags) == "table" and table.concat(w.tags, " ") or (w.tags or "")
	if not tags:find("desktop") then
		return
	end
	hl.dispatch(hl.dsp.window.tag({ tag = "-desktop", window = w }))
	hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
end

hl.on("window.open", function(w)
	if w.workspace and desktop[w.workspace.name] then
		makeFloat(w, true)
	end
end)

-- Al mover una ventana entre workspaces se adapta al modo del destino
-- (minimizar es moverla a un special: esa no se toca)
hl.on("window.move_to_workspace", function(w, ws)
	ws = ws or w.workspace
	if not ws or ws.special then
		return
	end
	if desktop[ws.name] then
		makeFloat(w, false)
	else
		makeTiled(w)
	end
end)

hl.bind("SUPER + ALT + D", function()
	local ws = hl.get_active_workspace()
	if not ws then
		return
	end
	desktop[ws.name] = not desktop[ws.name] or nil
	save()
	local windows = hl.get_workspace_windows(ws)
	for _, w in ipairs(windows) do
		if desktop[ws.name] then
			-- Si estaba sola ocupaba toda la pantalla: se pone al tamaño de las nuevas
			makeFloat(w, #windows == 1)
		else
			makeTiled(w)
		end
	end
end, { description = "Modo escritorio" })

hl.bind("SUPER + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }), { description = "Minimizar" })

-- Snap como macOS: al soltar una ventana arrastrada con el cursor pegado al borde
--   izquierda/derecha → media pantalla   arriba → maximizar y minimizar el resto
-- No hay evento de "fin de arrastre": con Super se escucha el clic izquierdo
-- (sin consumirlo) y se compara la posición al pulsar y al soltar; con la barra
-- de título avisa hyprbars (opción on_drag_end, parche local del plugin).
local EDGE = 4 -- píxeles de margen para considerar "pegado al borde"
local TITLEBAR = 28 -- alto de la barra de hyprbars: se dibuja encima de w.at
local pressedAt
local snapped = {} -- tamaño previo de las ventanas en media pantalla, por dirección

local function snapTarget()
	local w = hl.get_active_window()
	if not (w and w.floating and w.workspace and desktop[w.workspace.name]) then
		return nil
	end
	local tags = type(w.tags) == "table" and table.concat(w.tags, " ") or (w.tags or "")
	return tags:find("desktop") and w or nil
end

hl.bind("mouse:272", function()
	local w = snapTarget()
	pressedAt = w and { x = w.at.x, y = w.at.y } or nil
end, { non_consuming = true, transparent = true, ignore_mods = true })

-- Global para poder llamarla con `hyprctl eval 'DesktopSnap()'` desde hyprbars
function DesktopSnap()
	local w = snapTarget()
	if not w then
		return
	end
	local c, m = hl.get_cursor_pos(), hl.get_monitor_at_cursor()
	if not (c and m) then
		return
	end
	local r = m.reserved
	local mx, my = m.x + r.left, m.y + r.top + TITLEBAR
	local mw = math.floor(m.width / m.scale) - r.left - r.right
	local mh = math.floor(m.height / m.scale) - r.top - r.bottom - TITLEBAR

	if c.x <= m.x + EDGE or c.x >= m.x + m.width / m.scale - EDGE then
		snapped[w.address] = snapped[w.address] or { x = w.size.x, y = w.size.y }
		local half = math.floor(mw / 2)
		local x = c.x <= m.x + EDGE and mx or mx + mw - half
		hl.dispatch(hl.dsp.window.resize({ x = half, y = mh, window = w }))
		hl.dispatch(hl.dsp.window.move({ x = x, y = my, window = w }))
	elseif c.y <= m.y + EDGE then
		for _, other in ipairs(hl.get_workspace_windows(w.workspace)) do
			if other.address ~= w.address then
				hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = other }))
			end
		end
		hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = w }))
	end
end

-- Al empezar a arrastrar una ventana en media pantalla recupera su tamaño, con el
-- cursor en la misma proporción de la barra para que no se quede fuera de ella.
-- Tiene que ir antes de que Hyprland "coja" la ventana: hyprbars la llama de forma
-- síncrona (on_drag_start_eval) y con Super el drag_threshold de abajo da margen.
function DesktopUnsnap()
	local w = snapTarget()
	local old = w and snapped[w.address]
	local c = hl.get_cursor_pos()
	if not (old and c) then
		return
	end
	snapped[w.address] = nil
	-- se calcula antes del resize: Hyprland redimensiona manteniendo el centro y w.at cambia
	local x, y = math.floor(c.x - (c.x - w.at.x) * old.x / w.size.x), w.at.y
	hl.dispatch(hl.dsp.window.resize({ x = old.x, y = old.y, window = w }))
	hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = w }))
end

hl.config({ binds = { drag_threshold = 4 } })
hl.bind("SUPER + mouse:272", DesktopUnsnap, { non_consuming = true, transparent = true })

hl.on("window.close", function(w)
	snapped[w.address] = nil
end)

hl.bind("mouse:272", function()
	local w, from = snapTarget(), pressedAt
	pressedAt = nil
	if w and from and (w.at.x ~= from.x or w.at.y ~= from.y) then -- arrastre, no un clic
		DesktopSnap()
	end
end, { release = true, non_consuming = true, transparent = true, ignore_mods = true })

-- Barra de título (cerrar y maximizar) en las ventanas del modo escritorio.
-- Es el plugin hyprbars de hyprwm/hyprland-plugins, compilado a mano: si tras
-- actualizar Hyprland sale "version mismatch", recompílalo con el mismo tag:
--   git clone https://github.com/hyprwm/hyprland-plugins && cd hyprland-plugins
--   git checkout v<versión> && git apply ~/.config/hypr/hyprbars-on-drag-end.patch
--   make -C hyprbars all   (el parche añade on_drag_end y on_drag_start_eval, que usa el snap)
--   cp hyprbars/hyprbars.so ~/.local/lib/hyprland/
local HYPRBARS = os.getenv("HOME") .. "/.local/lib/hyprland/hyprbars.so"
local MAXIMIZE = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']]

if io.open(HYPRBARS) then
	hl.plugin.load(HYPRBARS)
end

if hl.plugin.hyprbars then
	hl.config({
		plugin = {
			hyprbars = {
				bar_height = TITLEBAR,
				bar_color = THEME_BG,
				col = { text = "rgba(d9d6e6ff)" },
				bar_text_font = "JetBrainsMono Nerd Font Propo",
				bar_text_size = 11,
				bar_text_align = "left",
				bar_padding = 10,
				bar_button_padding = 8,
				bar_part_of_window = true,
				bar_precedence_over_border = true,
				on_double_click = MAXIMIZE,
				on_drag_end = [[hyprctl eval 'DesktopSnap()']],
				on_drag_start_eval = "DesktopUnsnap()",
			},
		},
	})
	-- Se añaden de derecha a izquierda: × queda en la esquina
	hl.plugin.hyprbars.add_button({ bg_color = "rgba(e89bd0ff)", fg_color = THEME_BG, size = 12, icon = "×", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
	hl.plugin.hyprbars.add_button({ bg_color = "rgba(86d4dcff)", fg_color = THEME_BG, size = 12, icon = "□", action = MAXIMIZE })
	hl.plugin.hyprbars.add_button({ bg_color = "rgba(a99bd6ff)", fg_color = THEME_BG, size = 12, icon = "–", action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:minimized", follow = false })']] })
	-- Solo las ventanas que ha hecho flotar el modo escritorio llevan barra
	hl.window_rule({ match = { tag = "negative:desktop" }, ["hyprbars:no_bar"] = true })
end
