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

    function raise() { set(percent + 5); }
    function lower() { set(percent - 5); }

    // Valor (en %) que falta por aplicar: al arrastrar llegan valores mientras
    // brightnessctl aún corre; se guarda el último y se aplica al terminar
    property int pending: -1

    function set(p) {
        if (!available)
            return;
        // percent cambia ya, así la barra sigue al ratón y las teclas se acumulan
        percent = pending = Math.max(1, Math.min(100, Math.round(p)));
        if (!setter.running)
            apply();
    }

    function apply() {
        // -d: siempre el panel detectado (sin él brightnessctl podría coger un LED)
        setter.command = ["brightnessctl", "-d", device.split("/").pop(), "--min-value=1", "set", pending + "%"];
        pending = -1;
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
        onExited: root.pending >= 0 ? root.apply() : current.reload()
    }

    // sysfs no avisa de cambios, así que se consulta cada pocos segundos
    // (por si cambias el brillo con las teclas)
    Timer {
        interval: 2000
        running: root.available
        repeat: true
        // Mientras se aplica un cambio, leerlo daría el valor viejo
        onTriggered: if (!setter.running) current.reload()
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
