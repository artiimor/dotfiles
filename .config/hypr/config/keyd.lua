-- Teclado en Hyprland: en este equipo /etc/keyd/*.conf sigue al estilo Mac de cuando
-- se probó Plasma (Super = Option, Alt = Cmd/Ctrl), y así Hyprland nunca recibiría
-- Super. Al arrancar Hyprland se cambia en caliente al esquema de siempre:
-- solo se intercambian Alt y Super izquierdos, y se quitan los atajos Mac de la capa
-- Option. Con el thinkpad.conf de este repo (system/etc/keyd, solo el intercambio)
-- el resultado es el mismo. "keyd bind reset" sin argumentos vuelve a /etc/keyd.
-- Necesita estar en el grupo keyd (install.sh lo hace; hay que volver a entrar).
-- Solo se aplica si keyd está instalado y existe /etc/keyd/thinkpad.conf (lo pone
-- install.sh si se elige keyd): en otros equipos no se toca el teclado.
local binds = {
	"main.leftalt=layer(meta)",
	"main.leftmeta=layer(alt)",
	-- Ojo: en keyd una tecla asignada explícitamente en una capa pierde el modificador
	-- de esa capa, así que "alt.space=space" mandaba Espacio SIN Alt (Super+Alt+Espacio
	-- llegaba como Super+Espacio). Por eso se reasignan con el Alt puesto: A-<tecla>.
	"alt.left=A-left", "alt.right=A-right", "alt.backspace=A-backspace",
	"alt.c=A-c", "alt.v=A-v", "alt.w=A-w", "alt.f=A-f",
	"alt.space=A-space", "alt.enter=A-enter",
}
for i = 1, 5 do
	table.insert(binds, "alt." .. i .. "=A-" .. i)
	table.insert(binds, "alt+shift." .. i .. "=A-S-" .. i)
end
-- HHKB: sin swap (◇ = Super, Alt = Alt). Van al final para pisar el swap de arriba,
-- y usan los aliases de /etc/keyd/hhkb.conf, que solo existen en ese teclado.
table.insert(binds, "main.hhdiamond=layer(meta)")
table.insert(binds, "main.hhalt=layer(alt)")

hl.on("hyprland.start", function()
	hl.exec_cmd("[ -e /etc/keyd/thinkpad.conf ] && command -v keyd >/dev/null && keyd bind reset '"
		.. table.concat(binds, "' '") .. "'")
end)
