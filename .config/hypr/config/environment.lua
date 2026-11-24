-- Environmental variables (for reference https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/)
-- if you use UWSM, define your variables in ~/.config/uwsm/env
-- if you don't use UWSM, define your variables here (e.g. hl.env("QT_QPA_PLATFORM", "wayland"))

-- if you have an NVIDIA GPU uncomment the following lines:

-- hl.env("GBM_BACKEND", "nvidia-drm") -- force GBM as a backend
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia") -- force GBM as a backend
-- hl.env("LIBVA_DRIVER_NAME", "nvidia") -- Hardware acceleration on NVIDIA GPUs
-- hl.env("__GL_GSYNC_ALLOWED", "1") -- Controls if G-Sync capable monitors should use Variable Refresh Rate (VRR)

-- Las variables viven solo en ~/.config/uwsm/env (que solo lee la sesión con uwsm):
-- aquí se leen sus líneas `export K=V` para que la sesión "Hyprland" sin uwsm quede igual.
-- Con uwsm no cambia nada: son los mismos valores. Si el archivo no está, no se pone nada.
local SKIP = { TERM = true } -- TERM es cosa del terminal, Hyprland no lo exporta

local function parse(line)
	local k, v = line:match("^%s*export%s+([%a_][%w_]*)=(.*)$")
	if not k then return nil end
	local q = v:sub(1, 1)
	if q == '"' or q == "'" then
		v = v:match("^" .. q .. "(.-)" .. q) or v:sub(2)
	else
		v = v:gsub("%s+#.*$", ""):gsub("%s+$", "")
	end
	return k, v
end

local f = io.open(os.getenv("HOME") .. "/.config/uwsm/env")
if f then
	for line in f:lines() do
		local ok, k, v = pcall(parse, line)
		if ok and k and not SKIP[k] then hl.env(k, v) end
	end
	f:close()
end
