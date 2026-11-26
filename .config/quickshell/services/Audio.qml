// Salida de audio por defecto: volumen, silencio e icono. Lo comparten la
// barra, el OSD y el panel de notificaciones. Si no hay salida, todo queda a
// cero y las funciones no hacen nada.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0   // 1 = 100 % (puede pasar de 1)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool bluetooth: (sink?.name ?? "").startsWith("bluez")
    readonly property string icon: muted ? "󰝟" : ["󰕿", "󰖀", "󰕾"][Math.min(2, Math.floor(volume * 3))]

    // Sin esto Pipewire no rellena sink.audio
    PwObjectTracker { objects: [root.sink] }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !muted;
    }

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = v;
    }

    // Rueda de la barra: ±delta con la misma regla que los sliders (Theme.wheelStep)
    function step(delta) {
        setVolume(Theme.wheelStep(volume, delta));
    }
}
