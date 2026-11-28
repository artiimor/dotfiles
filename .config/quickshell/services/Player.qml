// Music player (MPRIS) shown by the bar and the notification
// panel: the one playing or, if none, the first one there is.
// playerctld is a playerctl "proxy", not a real player: out.
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
