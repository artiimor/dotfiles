// Brillo de la pantalla (lee /sys, cambia con brightnessctl). Solo hay algo
// que controlar si existe un panel con retroiluminación (/sys/class/backlight):
// en un sobremesa no lo hay y `available` queda en false, así la barra, el
// panel de notificaciones y el OSD esconden el brillo.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Panel de /sys/class/backlight, por tipo raw > platform > firmware (así no se coge
    // un acpi_video0 muerto si hay intel_backlight); "" si no hay ninguno
    property string device: ""
    readonly property bool available: device !== ""
    property int percent: 0

    function raise() { set("5%+"); }
    function lower() { set("5%-"); }

    function set(value) {
        if (!available)
            return;
        // -d: siempre el panel detectado (sin él brightnessctl podría coger un LED)
        setter.command = ["brightnessctl", "-d", device.split("/").pop(), "--min-value=1", "set", value];
        setter.running = true;
    }

    // Para las teclas de brillo de Hyprland: qs ipc call brightness up/down
    IpcHandler {
        target: "brightness"
        function up(): void { root.raise(); }
        function down(): void { root.lower(); }
    }

    // Busca el panel una vez al arrancar
    Process {
        running: true
        command: ["sh", "-c", "for t in raw platform firmware; do for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && [ \"$(cat \"$d/type\" 2>/dev/null)\" = $t ] && { echo \"$d\"; exit; }; done; done"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    Process {
        id: setter
        onExited: current.reload()
    }

    // sysfs no avisa de cambios, así que se consulta cada pocos segundos
    // (por si cambias el brillo con las teclas)
    Timer {
        interval: 2000
        running: root.available
        repeat: true
        onTriggered: current.reload()
    }

    FileView {
        id: max
        path: root.available ? root.device + "/max_brightness" : ""
    }
    FileView {
        id: current
        path: root.available ? root.device + "/brightness" : ""
        onLoaded: {
            const m = Number(max.text());
            if (m > 0)
                root.percent = Math.round(100 * Number(text()) / m);
        }
    }
}
