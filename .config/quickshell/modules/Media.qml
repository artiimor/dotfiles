// Música (MPRIS): solo aparece cuando hay un reproductor.
// Clic: pausa · Rueda: cambiar canción
import QtQuick
import qs
import qs.components
import qs.services

Island {
    id: root
    padding: 3

    visible: Player.player !== null

    BarIcon {
        // Mismo criterio que Waybar: muestra el botón de lo que hará el clic
        icon: (Player.playing ? "󰏤" : "󰐊") + "  " + root.trackText()
        padding: 14
        pixelSize: Theme.fontSize
        italic: !Player.playing
        color: Player.playing ? Theme.accent : Theme.muted
        tooltip: Player.player ? `${Player.player.identity}: ${Player.player.trackTitle}\n${Player.player.trackArtist} · ${Player.player.trackAlbum}\nClic: pausa · Rueda: cambiar canción` : ""

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
