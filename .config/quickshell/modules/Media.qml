// Música (MPRIS): solo aparece cuando hay un reproductor.
// Clic: pausa · Rueda: cambiar canción
import QtQuick
import Quickshell.Services.Mpris
import qs
import qs.components

Island {
    id: root
    padding: 3

    // Prioriza el que está sonando; si no, el primero que haya.
    // playerctld es un "proxy" de playerctl, no un reproductor de verdad: fuera
    readonly property MprisPlayer player: {
        const ps = Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"));
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }
    readonly property bool playing: player?.isPlaying ?? false

    visible: player !== null

    BarIcon {
        // Mismo criterio que Waybar: muestra el botón de lo que hará el clic
        icon: (root.playing ? "󰏤" : "󰐊") + "  " + root.trackText()
        pixelSize: Theme.fontSize
        italic: !root.playing
        color: root.playing ? Theme.accent : Theme.muted
        tooltip: root.player ? `${root.player.identity}: ${root.player.trackTitle}\n${root.player.trackArtist} · ${root.player.trackAlbum}\nClic: pausa · Rueda: cambiar canción` : ""

        onClicked: root.player.togglePlaying()
        onScrolledUp: root.player.previous()
        onScrolledDown: root.player.next()
    }

    function trackText() {
        if (!player)
            return "";
        const parts = [player.trackTitle, player.trackArtist].filter(s => s);
        const t = parts.join(" - ");
        return t.length > 40 ? t.slice(0, 39) + "…" : t;
    }
}
