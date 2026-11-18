-- Teclado en Hyprland: keyd está configurado al estilo Mac para Plasma
-- (/etc/keyd/*.conf: Super = Option, Alt = Cmd/Ctrl) y así Hyprland nunca recibe
-- Super. Al arrancar Hyprland se cambia en caliente al esquema de antes:
-- solo se intercambian Alt y Super izquierdos, y se quitan los atajos Mac de la capa
-- Option. Plasma vuelve a dejarlo como en /etc/keyd con "keyd bind reset"
-- (~/.config/autostart/keyd-plasma.desktop, repo plasma-mac).
-- Necesita estar en el grupo keyd (sudo usermod -aG keyd $USER y volver a entrar).
local binds = {
	"main.leftalt=layer(meta)",
	"main.leftmeta=layer(alt)",
	"alt.left=left", "alt.right=right", "alt.backspace=backspace",
	"alt.c=c", "alt.v=v", "alt.w=w", "alt.f=f",
	"alt.space=space", "alt.enter=enter",
}
for i = 1, 5 do
	table.insert(binds, "alt." .. i .. "=" .. i)
	table.insert(binds, "alt+shift." .. i .. "=" .. i)
end
-- HHKB: sin swap (◇ = Super, Alt = Alt). Van al final para pisar el swap de arriba,
-- y usan los aliases de /etc/keyd/hhkb.conf, que solo existen en ese teclado.
table.insert(binds, "main.hhdiamond=layer(meta)")
table.insert(binds, "main.hhalt=layer(alt)")

hl.on("hyprland.start", function()
	hl.exec_cmd("keyd bind reset '" .. table.concat(binds, "' '") .. "'")
end)
