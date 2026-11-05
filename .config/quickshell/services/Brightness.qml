// Brillo de la pantalla del portátil (lee /sys, cambia con brightnessctl).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string device: "/sys/class/backlight/amdgpu_bl1"
    property int percent: 0

    function raise() { set("5%+"); }
    function lower() { set("5%-"); }

    function set(value) {
        setter.command = ["brightnessctl", "--min-value=1", "set", value];
        setter.running = true;
    }

    // Para las teclas de brillo de Hyprland: qs ipc call brightness up/down
    IpcHandler {
        target: "brightness"
        function up(): void { root.raise(); }
        function down(): void { root.lower(); }
    }

    Process {
        id: setter
        onExited: current.reload()
    }

    // sysfs no avisa de cambios, así que se consulta cada pocos segundos
    // (por si cambias el brillo con las teclas)
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: current.reload()
    }

    FileView {
        id: max
        path: root.device + "/max_brightness"
    }
    FileView {
        id: current
        path: root.device + "/brightness"
        onLoaded: {
            const m = Number(max.text());
            if (m > 0)
                root.percent = Math.round(100 * Number(text()) / m);
        }
    }
}
