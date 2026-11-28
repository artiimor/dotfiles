// Music (MPRIS): only shows when there is a player.
// Click: pause · Wheel: change song
import QtQuick
import qs
import qs.components
import qs.services

Island {
    id: root
    padding: 3

    visible: Player.player !== null

    BarIcon {
        // Same rule as Waybar: shows the button for what the click will do
        icon: (Player.playing ? "󰏤" : "󰐊") + "  " + root.trackText()
        padding: 14
        pixelSize: Theme.fontSize
        italic: !Player.playing
        color: Player.playing ? TopBar.accent : TopBar.muted
        tooltip: Player.player ? `${Player.player.identity}: ${Player.player.trackTitle}\n${Player.player.trackArtist} · ${Player.player.trackAlbum}\n` + I18n.tr("Click: pause · Wheel: change track") : ""

        onClicked: Player.player.togglePlaying()
        onScrolledUp: Player.player.previous()
        onScrolledDown: Player.player.next()
    }

    function trackText() {
        if (!Player.player)
            return "";
        const parts = [Player.player.trackTitle, Player.player.trackArtist].filter(s => s);
        const t = parts.join(" - ");
        return t.length > 40 ? t.slice(0, 39) + "…" : t;
    }
}
