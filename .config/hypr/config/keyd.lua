-- Keyboard in Hyprland: on this machine /etc/keyd/*.conf still follows the Mac style from when
-- Plasma was tried (Super = Option, Alt = Cmd/Ctrl), so Hyprland would never get
-- Super. When Hyprland starts it is switched on the fly to the usual layout:
-- only left Alt and Super are swapped, and the Mac shortcuts are removed from the
-- Option layer. With this repo's thinkpad.conf (system/etc/keyd, only the swap)
-- the result is the same. "keyd bind reset" with no arguments goes back to /etc/keyd.
-- Requires being in the keyd group (install.sh does it; you have to log in again).
-- Only applied if keyd is installed and /etc/keyd/thinkpad.conf exists (install.sh
-- puts it there if keyd is chosen): on other machines the keyboard is left alone.
local binds = {
	"main.leftalt=layer(meta)",
	"main.leftmeta=layer(alt)",
	-- Careful: in keyd a key explicitly bound inside a layer loses that layer's
	-- modifier, so "alt.space=space" sent Space WITHOUT Alt (Super+Alt+Space
	-- arrived as Super+Space). That's why they are rebound with Alt held: A-<key>.
	"alt.left=A-left", "alt.right=A-right", "alt.backspace=A-backspace",
	"alt.c=A-c", "alt.v=A-v", "alt.w=A-w", "alt.f=A-f",
	"alt.space=A-space", "alt.enter=A-enter",
}
for i = 1, 5 do
	table.insert(binds, "alt." .. i .. "=A-" .. i)
	table.insert(binds, "alt+shift." .. i .. "=A-S-" .. i)
end
-- HHKB: no swap (◇ = Super, Alt = Alt). They go last to override the swap above,
-- and use the aliases from /etc/keyd/hhkb.conf, which only exist on that keyboard.
table.insert(binds, "main.hhdiamond=layer(meta)")
table.insert(binds, "main.hhalt=layer(alt)")

hl.on("hyprland.start", function()
	hl.exec_cmd("[ -e /etc/keyd/thinkpad.conf ] && command -v keyd >/dev/null && keyd bind reset '"
		.. table.concat(binds, "' '") .. "'")
end)
