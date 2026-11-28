-- Per-workspace desktop mode: windows float,
-- can be minimized and Quickshell shows a dock at the bottom.
--   Super+Alt+D   toggle it on the current workspace
--   minimize with the hyprbars button (goes to special:minimized; restored from the dock)
--
-- Which workspaces float depends on the profile (profile.lua):
--   mac / mac-light  all numbered ones float; Super+Alt+D switches one to tiling
--   default          all tiling; Super+Alt+D switches one to floating
-- Each profile stores only its exceptions (so they survive reloads and profile
-- switches), and the final list of floating workspaces is written to
-- desktop-workspaces, which is what Quickshell (dock, bar numbers) and
-- macshell (boxed numbers) read.
local util = require("config.util")
local STATE = util.HOME .. "/.local/state/"
local stateFile = STATE .. "desktop-workspaces"
local exceptionsFile = STATE .. (PROFILE_MAC and "desktop-exceptions-mac" or "desktop-workspaces-default")
local appliedFile = STATE .. "desktop-applied-profile"
local MAX_WS = 99 -- numbered workspaces recorded as floating in mac (monitor*10 + n)
-- Minimize = move to this special without following it (hyprbars button)
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

-- Does this workspace float? (special and named ones, e.g. gaming, don't float by default)
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
save() -- on load: the public list always reflects the current profile

-- Size of new windows: fraction of the screen (in logical pixels,
-- hence the division by the scale)
local OPEN_SIZE = 0.65

-- The "desktop" tag marks windows we made float ourselves, so we don't
-- send back to tiling the ones floating because of a window rule (Dolphin, calculator...)
local function hasTag(w, tag)
	local tags = type(w.tags) == "table" and table.concat(w.tags, " ") or (w.tags or "")
	return (" " .. tags .. " "):find(" " .. tag .. " ", 1, true) ~= nil
end

-- Height of the hyprbars bar: it is drawn above w.at
local TITLEBAR = PROFILE_MAC and 32 or 28 -- mac: like Plasma's Sur-Gris title bar

-- Usable area of a monitor for a floating window (x, y, width, height): without the
-- reserved bars and leaving room for the title bar
local function usableArea(m)
	local r = m.reserved
	return m.x + r.left,
		m.y + r.top + TITLEBAR,
		math.floor(m.width / m.scale) - r.left - r.right,
		math.floor(m.height / m.scale) - r.top - r.bottom - TITLEBAR
end

-- When going from tiling to floating the window keeps its place (and the title bar
-- would end up under the top bar) or gets back a saved floating size that
-- may not fit: it is fitted into the usable area. It lives in window.update_state (below)
-- to cover every path: shortcut, gesture, moving to a desktop-mode workspace...
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
	-- resize first: Hyprland resizes keeping the centre and w.at changes
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

-- Adapt the window to its workspace's mode (floating in desktop mode, otherwise tiling)
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

-- When a window moves between workspaces it adapts to the target's mode
-- (minimizing is moving it to a special: that one is left alone)
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
			-- If it was alone it filled the whole screen: give it the size of new windows
			makeFloat(w, #windows == 1)
		else
			makeTiled(w)
		end
	end
end, { description = "Desktop mode" })

-- When switching between mac and default (config-set runs hyprctl reload) windows that
-- are already open adapt to their workspace's new mode
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

-- macOS-like snap: when releasing a dragged window with the cursor against the edge
--   left/right → half screen   top → maximize (same as the □ button)
-- There is no "drag end" event: with Super the left click is listened to
-- (without consuming it) and the press and release positions are compared; with the title
-- bar hyprbars reports it (on_drag_end option, local plugin patch).
local EDGE = 4 -- margin in pixels to count as "against the edge"
local pressedAt
local snapped = {} -- previous size of half-screen windows, by address

-- Active window if it is floating and on a desktop-mode workspace
local function snapTarget(w)
	w = w or hl.get_active_window()
	if w and w.floating and w.workspace and isDesktop(w.workspace.name) then
		return w
	end
end

-- Click on a floating or maximized window (on any workspace) = it is raised.
-- With follow_mouse = 1 hovering already focuses it but doesn't raise it, and clicking
-- a window that already has focus doesn't either: hence raising it by hand.
local function raise(w)
	if w.fullscreen == 0 then
		if w.floating then
			hl.dispatch(hl.dsp.window.bring_to_top()) -- w is the active one
		end
		return
	end
	-- A maximized/fullscreen window lives in its own layer: bring_to_top doesn't put it
	-- above the floating windows opened on top of it (allowed_over_fullscreen). Maximizing
	-- it again takes that permission away and they go behind.
	if not w.workspace then
		return
	end
	for _, o in ipairs(hl.get_workspace_windows(w.workspace)) do
		if o.allowed_over_fullscreen and o.visible and not o.pinned and o.address ~= w.address then
			-- The mode is saved first: w is alive and after the unset w.fullscreen is 0,
			-- which as a mode means real fullscreen
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

-- While dragging a desktop-mode window the cursor can't go up into the
-- top bar (reserved area): it is pushed back to its edge. Enabled when the drag
-- starts (DesktopUnsnap) and disabled on release (click or hyprbars' on_drag_end).
-- In case the release is missed, it turns off by itself with no desktop-mode window or after ~30 s.
local confineTicks = 0
local confine
confine = hl.timer(function()
	confineTicks = confineTicks + 1
	if confineTicks > 1875 or not snapTarget() then -- 1875 × 16 ms = 30 s
		confine:set_enabled(false)
		return
	end
	local c, m = hl.get_cursor_pos(), hl.get_monitor_at_cursor()
	if c and m and c.y < m.y + m.reserved.top then
		hl.dispatch(hl.dsp.cursor.move({ x = c.x, y = m.y + m.reserved.top }))
	end
end, { timeout = 16, type = "repeat" })
confine:set_enabled(false)

-- Global so it can be called with `hyprctl eval 'DesktopSnap()'` from hyprbars
function DesktopSnap()
	confine:set_enabled(false) -- end of a drag by the title bar (hyprbars)
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
	elseif c.y <= m.y + m.reserved.top + EDGE then -- dropping on the top bar counts as the edge
		hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = w }))
	elseif w.at.y < my then
		-- Like the macOS menu bar: the title bar never stays under the top bar
		hl.dispatch(hl.dsp.window.move({ x = w.at.x, y = my, window = w }))
	end
end

-- When starting to drag a half-screen window it gets its size back, with the
-- cursor at the same proportion of the bar so it doesn't end up outside it.
-- It must run before Hyprland "grabs" the window: hyprbars calls it
-- synchronously (on_drag_start_eval) and with Super the drag_threshold below gives margin.
function DesktopUnsnap()
	local w = snapTarget()
	if w then
		confineTicks = 0
		confine:set_enabled(true)
	end
	local old = w and snapped[w.address]
	local c = hl.get_cursor_pos()
	if not (old and c) then
		return
	end
	snapped[w.address] = nil
	-- computed before the resize: Hyprland resizes keeping the centre and w.at changes
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
	if w and from and (w.at.x ~= from.x or w.at.y ~= from.y) then -- a drag, not a click
		DesktopSnap()
	end
end, { release = true, non_consuming = true, transparent = true, ignore_mods = true })

-- Title bar (close, minimize and maximize) on floating windows.
-- It is the hyprbars plugin from hyprwm/hyprland-plugins, built by hand: if after
-- updating Hyprland it says "version mismatch", rebuild it with the same tag:
--   git clone https://github.com/hyprwm/hyprland-plugins && cd hyprland-plugins
--   git checkout v<version> && git apply ~/.config/hypr/hyprbars-on-drag-end.patch ~/.config/hypr/hyprbars-hover-icon.patch \
--     ~/.config/hypr/hyprbars-resize-top-edge.patch ~/.config/hypr/hyprbars-separator.patch
--   make -C hyprbars all   (the patches add on_drag_end and on_drag_start_eval, used by snap,
--                           hover_icon in add_button: the symbol changes on mouse hover,
--                           bar_resize_edge: the top edge of the bar resizes
--                           and col.separator: line between the bar and the window)
--   cp --remove-destination hyprbars/hyprbars.so ~/.local/lib/hyprland/   (new inode: the old one is loaded)
local HYPRBARS = util.HOME .. "/.local/lib/hyprland/hyprbars.so"
local MAXIMIZE = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']]

if util.exists(HYPRBARS) then
	hl.plugin.load(HYPRBARS)
end

-- Bar font in Normal Mode: the one chosen with font-set (the line in
-- hypr/font.conf that isn't a comment) or, if there is none, JetBrains Mono
local function barFont()
	for line in pairs(readLines(util.HOME .. "/.config/hypr/font.conf")) do
		if not line:match("^#") then
			return line
		end
	end
	return "JetBrainsMono Nerd Font Propo"
end

if hl.plugin.hyprbars then
	local BAR_TEXT = CONTRAST and (PROFILE_LIGHT and "rgba(000000ff)" or PROFILE_MAC and "rgba(ffffffff)")
		or PROFILE_LIGHT and "rgba(3c3c43ff)" or PROFILE_MAC and "rgba(e1e1e1ff)" or THEME_FG or "rgba(d9d6e6ff)"
	hl.config({
		plugin = {
			hyprbars = {
				bar_height = TITLEBAR,
				-- mac: colors, font and sizes of Plasma's Sur-Gris decoration;
				-- default: the color theme's background and text and the font-set font
				-- mac-light: macOS light grey with dark text
				bar_color = PROFILE_LIGHT and "rgba(ececedff)" or PROFILE_MAC and "rgba(2d2d2dff)" or THEME_BG,
				-- With CONTRAST (increase contrast) the text is pure black or white and there is a
				-- line in the text color between the bar and the window (col.separator, local patch)
				col = {
					text = BAR_TEXT,
					separator = CONTRAST and BAR_TEXT:gsub("%x%x%)$", "73)") or "rgba(00000000)",
				},
				bar_text_font = PROFILE_MAC and "Noto Sans" or barFont(),
				bar_text_size = PROFILE_MAC and 10 or 11,
				bar_text_align = "center",
				bar_padding = PROFILE_MAC and 16 or 10,
				bar_button_padding = PROFILE_MAC and 10 or 8,
				-- macOS style: buttons on the left, a dot that turns into its symbol on hover (hover_icon),
				-- all grey (dimmer on unfocused windows)
				bar_buttons_alignment = "left",
				icon_on_hover = true,
				inactive_button_color = PROFILE_LIGHT and (CONTRAST and "rgba(c7c7ccdd)" or "rgba(c7c7cc88)")
					or (CONTRAST and "rgba(8e8e93bb)" or "rgba(8e8e9355)"),
				bar_part_of_window = true,
				bar_precedence_over_border = true,
				-- Local patch: the top 6 px of the bar and what sticks out above it
				-- (border_size + extend_border_grab_area) resize like the other edges
				bar_resize_edge = 6,
				on_double_click = MAXIMIZE,
				on_drag_end = [[hyprctl eval 'DesktopSnap()']],
				on_drag_start_eval = "DesktopUnsnap()",
			},
		},
	})
	local BUTTON_BG = PROFILE_LIGHT and "rgba(aeaeb2ff)" or "rgba(8e8e93ff)"
	local BUTTON_FG = PROFILE_LIGHT and "rgba(3a3a3ccc)" or "rgba(2c2c2ecc)"
	-- Left-aligned buttons are added left to right: close, minimize, maximize
	hl.plugin.hyprbars.add_button({ bg_color = BUTTON_BG, fg_color = BUTTON_FG, size = 12, icon = "·", hover_icon = "×", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
	hl.plugin.hyprbars.add_button({ bg_color = BUTTON_BG, fg_color = BUTTON_FG, size = 12, icon = "·", hover_icon = "–", action = "hyprctl dispatch 'hl.dsp.window.move({ workspace = \"" .. MINIMIZED .. "\", follow = false })'" })
	hl.plugin.hyprbars.add_button({ bg_color = BUTTON_BG, fg_color = BUTTON_FG, size = 12, icon = "·", hover_icon = "+", action = MAXIMIZE })
	-- Bar on every floating window, whether in desktop mode or not
	hl.window_rule({ match = { float = false }, ["hyprbars:no_bar"] = true })
end
