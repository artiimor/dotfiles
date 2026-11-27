-- Modo escritorio por workspace: las ventanas flotan,
-- se pueden minimizar y Quickshell enseña un dock abajo.
--   Super+Alt+D   activar/desactivar en el workspace actual
--   Super+M       minimizar (va a special:minimized; se recupera desde el dock)
--
-- Qué workspaces flotan depende del perfil (profile.lua):
--   mac / mac-light  todos los numerados flotan; Super+Alt+D pasa uno a tiling
--   default          todos en tiling; Super+Alt+D pasa uno a flotante
-- Cada perfil guarda solo sus excepciones (así sobreviven a recargas y a cambiar
-- de perfil), y la lista final de workspaces flotantes se escribe en
-- desktop-workspaces, que es lo que leen Quickshell (dock, números de la barra) y
-- macshell (números en cajita).
local util = require("config.util")
local STATE = util.HOME .. "/.local/state/"
local stateFile = STATE .. "desktop-workspaces"
local exceptionsFile = STATE .. (PROFILE_MAC and "desktop-exceptions-mac" or "desktop-workspaces-default")
local appliedFile = STATE .. "desktop-applied-profile"
local MAX_WS = 99 -- workspaces numerados que se apuntan como flotantes en mac (monitor*10 + n)
-- Minimizar = mover a este special sin seguirla (Super+M y el botón de hyprbars)
local MINIMIZED = "special:minimized"

local function readLines(path)
	local set, fh = {}, io.open(path)
	if fh then
		for name in fh:lines() do
			if name ~= "" then
				set[name] = true
			end
		end
		fh:close()
	end
	return set
end

local function writeLines(path, lines)
	local out = io.open(path, "w")
	if not out then
		return
	end
	for _, name in ipairs(lines) do
		out:write(name, "\n")
	end
	out:close()
end

local exceptions = readLines(exceptionsFile)

-- ¿Flota este workspace? (los especiales y con nombre, p.ej. gaming, no flotan por defecto)
local function isDesktop(name)
	local base = PROFILE_MAC and tonumber(name) ~= nil
	return base ~= (exceptions[name] == true)
end

local function save()
	local ex, public = {}, {}
	for name in pairs(exceptions) do
		ex[#ex + 1] = name
		if not tonumber(name) and isDesktop(name) then
			public[#public + 1] = name
		end
	end
	writeLines(exceptionsFile, ex)
	if PROFILE_MAC then
		for i = 1, MAX_WS do
			if isDesktop(tostring(i)) then
				public[#public + 1] = tostring(i)
			end
		end
	else
		public = ex
	end
	writeLines(stateFile, public)
end
save() -- al cargar: la lista pública siempre refleja el perfil actual

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
local TITLEBAR = PROFILE_MAC and 32 or 28 -- mac: como la barra Sur-Gris de Plasma

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

-- Adapta la ventana al modo de su workspace (flotante en modo escritorio, si no tiling)
local function applyMode(w, ws)
	if isDesktop(ws.name) then
		makeFloat(w, false)
	else
		makeTiled(w)
	end
end

hl.on("window.update_state", function(w, changes)
	if changes and changes.float ~= nil then
		fitOnScreen(w)
	end
end)

hl.on("window.open", function(w)
	if w.workspace and isDesktop(w.workspace.name) then
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
	applyMode(w, ws)
end)

hl.bind("SUPER + ALT + D", function()
	local ws = hl.get_active_workspace()
	if not ws then
		return
	end
	local on = not isDesktop(ws.name)
	exceptions[ws.name] = not exceptions[ws.name] or nil
	save()
	local windows = hl.get_workspace_windows(ws)
	for _, w in ipairs(windows) do
		if on then
			-- Si estaba sola ocupaba toda la pantalla: se pone al tamaño de las nuevas
			makeFloat(w, #windows == 1)
		else
			makeTiled(w)
		end
	end
end, { description = "Desktop mode" })

-- Al cambiar entre mac y default (config-set hace hyprctl reload) las ventanas que
-- ya están abiertas se adaptan al modo nuevo de su workspace
local family = PROFILE_MAC and "mac" or "default"
if not readLines(appliedFile)[family] then
	for _, w in ipairs(hl.get_windows()) do
		local ws = w.workspace
		if ws and not ws.special then
			applyMode(w, ws)
		end
	end
	writeLines(appliedFile, { family })
end

hl.bind("SUPER + M", hl.dsp.window.move({ workspace = MINIMIZED, follow = false }), { description = "Minimize" })

-- Snap como macOS: al soltar una ventana arrastrada con el cursor pegado al borde
--   izquierda/derecha → media pantalla   arriba → maximizar (igual que el botón □)
-- No hay evento de "fin de arrastre": con Super se escucha el clic izquierdo
-- (sin consumirlo) y se compara la posición al pulsar y al soltar; con la barra
-- de título avisa hyprbars (opción on_drag_end, parche local del plugin).
local EDGE = 4 -- píxeles de margen para considerar "pegado al borde"
local pressedAt
local snapped = {} -- tamaño previo de las ventanas en media pantalla, por address

-- Ventana activa si es flotante y está en un workspace en modo escritorio
local function snapTarget(w)
	w = w or hl.get_active_window()
	if w and w.floating and w.workspace and isDesktop(w.workspace.name) then
		return w
	end
end

-- Clic en una ventana flotante o maximizada (de cualquier workspace) = sale delante.
-- Con follow_mouse = 1 el hover ya le da el foco pero no la sube, y el clic sobre
-- una ventana que ya tiene el foco tampoco: por eso se sube a mano.
local function raise(w)
	if w.fullscreen == 0 then
		if w.floating then
			hl.dispatch(hl.dsp.window.bring_to_top()) -- w es la activa
		end
		return
	end
	-- Una maximizada/pantalla completa va en su propia capa: bring_to_top no la pone
	-- sobre las flotantes que se abrieron encima (allowed_over_fullscreen). Volver a
	-- maximizarla les quita ese permiso y quedan detrás.
	if not w.workspace then
		return
	end
	for _, o in ipairs(hl.get_workspace_windows(w.workspace)) do
		if o.allowed_over_fullscreen and o.visible and not o.pinned and o.address ~= w.address then
			-- El modo se guarda antes: w está vivo y tras el unset w.fullscreen vale 0,
			-- que como modo significa pantalla completa total
			local mode = w.fullscreen == 1 and "maximized" or "fullscreen"
			hl.dispatch(hl.dsp.window.fullscreen({ mode = mode, action = "unset", window = w }))
			hl.dispatch(hl.dsp.window.fullscreen({ mode = mode, action = "set", window = w }))
			return
		end
	end
end

hl.bind("mouse:272", function()
	local active = hl.get_active_window()
	if active then
		raise(active)
	end
	local w = snapTarget(active)
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

	local atLeft = c.x <= m.x + EDGE
	if atLeft or c.x >= m.x + m.width / m.scale - EDGE then
		snapped[w.address] = snapped[w.address] or { x = w.size.x, y = w.size.y }
		local half = math.floor(mw / 2)
		local x = atLeft and mx or mx + mw - half
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
--   git checkout v<versión> && git apply ~/.config/hypr/hyprbars-on-drag-end.patch ~/.config/hypr/hyprbars-hover-icon.patch \
--     ~/.config/hypr/hyprbars-resize-top-edge.patch
--   make -C hyprbars all   (los parches añaden on_drag_end y on_drag_start_eval, que usa el snap,
--                           hover_icon en add_button: el símbolo cambia al pasar el ratón,
--                           y bar_resize_edge: el borde de arriba de la barra redimensiona)
--   cp --remove-destination hyprbars/hyprbars.so ~/.local/lib/hyprland/   (inodo nuevo: el viejo está cargado)
local HYPRBARS = util.HOME .. "/.local/lib/hyprland/hyprbars.so"
local MAXIMIZE = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']]

if util.exists(HYPRBARS) then
	hl.plugin.load(HYPRBARS)
end

-- Fuente de la barra en Modo normal: la elegida con font-set (la línea de
-- hypr/font.conf que no es comentario) o, si no hay, JetBrains Mono
local function barFont()
	for line in pairs(readLines(util.HOME .. "/.config/hypr/font.conf")) do
		if not line:match("^#") then
			return line
		end
	end
	return "JetBrainsMono Nerd Font Propo"
end

if hl.plugin.hyprbars then
	hl.config({
		plugin = {
			hyprbars = {
				bar_height = TITLEBAR,
				-- mac: colores, fuente y medidas de la decoración Sur-Gris de Plasma;
				-- default: el fondo y el texto del tema de colores y la fuente de font-set
				-- mac-light: gris claro de macOS con texto oscuro
				bar_color = PROFILE_LIGHT and "rgba(ececedff)" or PROFILE_MAC and "rgba(2d2d2dff)" or THEME_BG,
				-- Con CONTRAST (aumentar contraste) el texto es negro o blanco puro
				col = {
					text = CONTRAST and (PROFILE_LIGHT and "rgba(000000ff)" or PROFILE_MAC and "rgba(ffffffff)")
						or PROFILE_LIGHT and "rgba(3c3c43ff)" or PROFILE_MAC and "rgba(e1e1e1ff)" or THEME_FG or "rgba(d9d6e6ff)",
				},
				bar_text_font = PROFILE_MAC and "Noto Sans" or barFont(),
				bar_text_size = PROFILE_MAC and 10 or 11,
				bar_text_align = "center",
				bar_padding = PROFILE_MAC and 16 or 10,
				bar_button_padding = PROFILE_MAC and 10 or 8,
				-- Estilo macOS: botones a la izquierda, un punto que cambia a su símbolo al pasar el ratón (hover_icon),
				-- todos grises (más apagados en las ventanas sin foco)
				bar_buttons_alignment = "left",
				icon_on_hover = true,
				inactive_button_color = PROFILE_LIGHT and (CONTRAST and "rgba(c7c7ccdd)" or "rgba(c7c7cc88)")
					or (CONTRAST and "rgba(8e8e93bb)" or "rgba(8e8e9355)"),
				bar_part_of_window = true,
				bar_precedence_over_border = true,
				-- Parche local: los 6 px de arriba de la barra y lo que sobresale por encima
				-- (border_size + extend_border_grab_area) redimensionan como los demás bordes
				bar_resize_edge = 6,
				on_double_click = MAXIMIZE,
				on_drag_end = [[hyprctl eval 'DesktopSnap()']],
				on_drag_start_eval = "DesktopUnsnap()",
			},
		},
	})
	local BUTTON_BG = PROFILE_LIGHT and "rgba(aeaeb2ff)" or "rgba(8e8e93ff)"
	local BUTTON_FG = PROFILE_LIGHT and "rgba(3a3a3ccc)" or "rgba(2c2c2ecc)"
	-- Alineados a la izquierda se añaden de izquierda a derecha: cerrar, minimizar, maximizar
	hl.plugin.hyprbars.add_button({ bg_color = BUTTON_BG, fg_color = BUTTON_FG, size = 12, icon = "·", hover_icon = "×", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
	hl.plugin.hyprbars.add_button({ bg_color = BUTTON_BG, fg_color = BUTTON_FG, size = 12, icon = "·", hover_icon = "–", action = "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"" .. MINIMIZED .. "\", follow = false })'" })
	hl.plugin.hyprbars.add_button({ bg_color = BUTTON_BG, fg_color = BUTTON_FG, size = 12, icon = "·", hover_icon = "+", action = MAXIMIZE })
	-- Barra en todas las ventanas flotantes, estén o no en modo escritorio
	hl.window_rule({ match = { float = false }, ["hyprbars:no_bar"] = true })
end
