// Reproductor de música (MPRIS) que enseñan la barra y el panel de
// notificaciones: el que está sonando o, si no, el primero que haya.
// playerctld es un "proxy" de playerctl, no un reproductor de verdad: fuera.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    readonly property MprisPlayer player: {
        const ps = Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"));
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }
    readonly property bool playing: player?.isPlaying ?? false
}
