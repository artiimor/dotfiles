-- Environmental variables (for reference https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/)
-- if you use UWSM, define your variables in ~/.config/uwsm/env
-- if you don't use UWSM, define your variables here (e.g. hl.env("QT_QPA_PLATFORM", "wayland"))

-- Las variables viven solo en ~/.config/uwsm/env (que solo lee la sesión con uwsm):
-- aquí se leen sus líneas `export K=V` para que la sesión "Hyprland" sin uwsm quede igual.
-- Con uwsm no cambia nada: son los mismos valores. Si el archivo no está, no se pone nada.
-- env.d/gpu lo genera install.sh según la gráfica (variables de NVIDIA); uwsm también lo lee.
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

for _, name in ipairs({ "env", "env.d/gpu" }) do
	local f = io.open(os.getenv("HOME") .. "/.config/uwsm/" .. name)
	if f then
		for line in f:lines() do
			local ok, k, v = pcall(parse, line)
			if ok and k then hl.env(k, v) end
		end
		f:close()
	end
end
