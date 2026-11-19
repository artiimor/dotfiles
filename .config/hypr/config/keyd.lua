-- Teclado en Hyprland: en este equipo /etc/keyd/*.conf sigue al estilo Mac de cuando
-- se probó Plasma (Super = Option, Alt = Cmd/Ctrl), y así Hyprland nunca recibiría
-- Super. Al arrancar Hyprland se cambia en caliente al esquema de siempre:
-- solo se intercambian Alt y Super izquierdos, y se quitan los atajos Mac de la capa
-- Option. Con el thinkpad.conf de este repo (system/etc/keyd, solo el intercambio)
-- el resultado es el mismo. "keyd bind reset" sin argumentos vuelve a /etc/keyd.
-- Necesita estar en el grupo keyd (install.sh lo hace; hay que volver a entrar).
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
