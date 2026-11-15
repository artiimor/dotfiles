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
local function hasTag(w, tag)
	local tags = type(w.tags) == "table" and table.concat(w.tags, " ") or (w.tags or "")
	return (" " .. tags .. " "):find(" " .. tag .. " ", 1, true) ~= nil
end

-- Alto de la barra de hyprbars: se dibuja encima de w.at
local TITLEBAR = 28

-- Zona útil de un monitor para una ventana flotante (x, y, ancho, alto): sin las
-- barras reservadas y dejando sitio a la barra de título
local function usableArea(m)
	local r = m.reserved
	return m.x + r.left,
		m.y + r.top + TITLEBAR,
		math.floor(m.width / m.scale) - r.left - r.right,
		math.floor(m.height / m.scale) - r.top - r.bottom - TITLEBAR
end

-- Al pasar de tiling a flotante la ventana conserva su sitio (y la barra de título
-- quedaría bajo la barra de arriba) o recupera un tamaño flotante guardado que
-- puede no caber: se encaja en la zona útil. Va en window.update_state (abajo)
-- para cubrir cualquier camino: atajo, gesto, mover a un workspace en modo escritorio...
local function fitOnScreen(w)
	local m = w and w.floating and w.monitor
	if not m then
		return
	end
	local left, top, areaW, areaH = usableArea(m)
	local x, y, width, height = w.at.x, w.at.y, w.size.x, w.size.y
	if x >= left and y >= top and x + width <= left + areaW and y + height <= top + areaH then
		return
	end
	width, height = math.min(width, areaW), math.min(height, areaH)
	x = math.max(left, math.min(x, left + areaW - width))
	y = math.max(top, math.min(y, top + areaH - height))
	-- primero el resize: Hyprland redimensiona manteniendo el centro y w.at cambia
	hl.dispatch(hl.dsp.window.resize({ x = width, y = height, window = w }))
	hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = w }))
end

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
	if not hasTag(w, "desktop") then
		return
	end
	hl.dispatch(hl.dsp.window.tag({ tag = "-desktop", window = w }))
	hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
end

hl.on("window.update_state", function(w, changes)
	if changes and changes.float ~= nil then
		fitOnScreen(w)
	end
end)

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
--   izquierda/derecha → media pantalla   arriba → maximizar (igual que el botón □)
-- No hay evento de "fin de arrastre": con Super se escucha el clic izquierdo
-- (sin consumirlo) y se compara la posición al pulsar y al soltar; con la barra
-- de título avisa hyprbars (opción on_drag_end, parche local del plugin).
local EDGE = 4 -- píxeles de margen para considerar "pegado al borde"
local pressedAt
local snapped = {} -- tamaño previo de las ventanas en media pantalla, por dirección

local function snapTarget()
	local w = hl.get_active_window()
	if not (w and w.floating and w.workspace and desktop[w.workspace.name]) then
		return nil
	end
	return w
end

hl.bind("mouse:272", function()
	local w = snapTarget()
	pressedAt = w and { x = w.at.x, y = w.at.y } or nil
end, { non_consuming = true, transparent = true, ignore_mods = true })

-- Mientras se arrastra una ventana del modo escritorio el cursor no puede subir a la
-- barra de arriba (zona reservada): se devuelve a su borde. Se activa al empezar el
-- arrastre (DesktopUnsnap) y se apaga al soltar (clic o on_drag_end de hyprbars).
local confine = hl.timer(function()
	local c, m = hl.get_cursor_pos(), hl.get_monitor_at_cursor()
	if c and m and c.y < m.y + m.reserved.top then
		hl.dispatch(hl.dsp.cursor.move({ x = c.x, y = m.y + m.reserved.top }))
	end
end, { timeout = 8, type = "repeat" })
confine:set_enabled(false)

-- Global para poder llamarla con `hyprctl eval 'DesktopSnap()'` desde hyprbars
function DesktopSnap()
	confine:set_enabled(false) -- fin del arrastre por la barra de título (hyprbars)
	local w = snapTarget()
	if not w then
		return
	end
	local c, m = hl.get_cursor_pos(), hl.get_monitor_at_cursor()
	if not (c and m) then
		return
	end
	local mx, my, mw, mh = usableArea(m)

	if c.x <= m.x + EDGE or c.x >= m.x + m.width / m.scale - EDGE then
		snapped[w.address] = snapped[w.address] or { x = w.size.x, y = w.size.y }
		local half = math.floor(mw / 2)
		local x = c.x <= m.x + EDGE and mx or mx + mw - half
		hl.dispatch(hl.dsp.window.resize({ x = half, y = mh, window = w }))
		hl.dispatch(hl.dsp.window.move({ x = x, y = my, window = w }))
	elseif c.y <= m.y + m.reserved.top + EDGE then -- soltar sobre la barra de arriba cuenta como borde
		hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = w }))
	elseif w.at.y < my then
		-- Como el menú de macOS: la barra de título nunca se queda debajo de la barra de arriba
		hl.dispatch(hl.dsp.window.move({ x = w.at.x, y = my, window = w }))
	end
end

-- Al empezar a arrastrar una ventana en media pantalla recupera su tamaño, con el
-- cursor en la misma proporción de la barra para que no se quede fuera de ella.
-- Tiene que ir antes de que Hyprland "coja" la ventana: hyprbars la llama de forma
-- síncrona (on_drag_start_eval) y con Super el drag_threshold de abajo da margen.
function DesktopUnsnap()
	local w = snapTarget()
	if w then
		confine:set_enabled(true)
	end
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
	confine:set_enabled(false)
	if w and from and (w.at.x ~= from.x or w.at.y ~= from.y) then -- arrastre, no un clic
		DesktopSnap()
	end
end, { release = true, non_consuming = true, transparent = true, ignore_mods = true })

-- Barra de título (cerrar, minimizar y maximizar) en las ventanas flotantes.
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
				bar_text_align = "center",
				bar_padding = 10,
				bar_button_padding = 8,
				-- Estilo macOS: botones a la izquierda, símbolo solo al pasar el ratón,
				-- y grises en las ventanas sin foco
				bar_buttons_alignment = "left",
				icon_on_hover = true,
				inactive_button_color = "rgba(80808099)",
				bar_part_of_window = true,
				bar_precedence_over_border = true,
				on_double_click = MAXIMIZE,
				on_drag_end = [[hyprctl eval 'DesktopSnap()']],
				on_drag_start_eval = "DesktopUnsnap()",
			},
		},
	})
	-- Alineados a la izquierda se añaden de izquierda a derecha: cerrar, minimizar, maximizar
	hl.plugin.hyprbars.add_button({ bg_color = "rgba(ff5f57ff)", fg_color = "rgba(4d0000cc)", size = 12, icon = "×", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
	hl.plugin.hyprbars.add_button({ bg_color = "rgba(febc2eff)", fg_color = "rgba(5a3e00cc)", size = 12, icon = "–", action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:minimized", follow = false })']] })
	hl.plugin.hyprbars.add_button({ bg_color = "rgba(28c840ff)", fg_color = "rgba(004d00cc)", size = 12, icon = "+", action = MAXIMIZE })
	-- Barra en todas las ventanas flotantes, estén o no en modo escritorio
	hl.window_rule({ match = { float = false }, ["hyprbars:no_bar"] = true })
end
