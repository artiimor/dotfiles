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
	for _, w in ipairs(hl.get_workspace_windows(ws)) do
		if desktop[ws.name] then
			makeFloat(w, false)
		else
			makeTiled(w)
		end
	end
end)

hl.bind("SUPER + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
