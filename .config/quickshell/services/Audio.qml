// Default audio output: volume, mute and icon. Shared by the
// bar, the OSD and the notification panel. With no output, everything stays at
// zero and the functions do nothing.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0   // 1 = 100 % (can go above 1)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool bluetooth: (sink?.name ?? "").startsWith("bluez")
    readonly property string icon: muted ? "󰝟" : ["󰕿", "󰖀", "󰕾"][Math.min(2, Math.floor(volume * 3))]

    // Without this Pipewire doesn't fill sink.audio
    PwObjectTracker { objects: [root.sink] }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !muted;
    }

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = v;
    }

    // Bar wheel: ±delta with the same rule as the sliders (Theme.wheelStep)
    function step(delta) {
        setVolume(Theme.wheelStep(volume, delta));
    }
}
