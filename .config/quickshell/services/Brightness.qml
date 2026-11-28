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
    // Icono según el nivel (tres tramos, como el del volumen)
    readonly property string icon: ["󰃞", "󰃟", "󰃠"][Math.min(2, Math.floor(percent / 100 * 3))]

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

    // Para las teclas de brillo de Hyprland: qs ipc call brightness up/down.
    // step: n pasos de 5 % de una vez, hacia arriba o abajo (la rueda de macshell);
    // devuelve si hay panel, así macshell sabe si tiene que cambiarlo por su cuenta
    IpcHandler {
        target: "brightness"
        function up(): void { root.raise(); }
        function down(): void { root.lower(); }
        function step(up: bool, n: int): bool {
            root.set(root.percent + (up ? 5 : -5) * n);
            return root.available;
        }
    }

    // Busca el panel una vez al arrancar (el mismo script que usa macshell)
    Process {
        running: true
        command: [Quickshell.shellDir + "/scripts/backlight-device"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    Process {
        id: setter
        onExited: root.pending >= 0 ? root.apply() : current.reload()
    }

    // sysfs no se puede vigilar, pero el kernel avisa de cada cambio del panel con un
    // uevent "change" (también cuando lo cambia otro, p. ej. brightnessctl a mano):
    // se relee en cada línea de udevadm en vez de consultar cada pocos segundos
    Process {
        running: root.available
        command: ["udevadm", "monitor", "-k", "-s", "backlight"]
        stdout: SplitParser {
            // Mientras se aplica un cambio no (al arrastrar, percent va por delante);
            // setter relee al terminar
            onRead: if (!setter.running) current.reload()
        }
    }

    // blockLoading: si no, `current` puede cargar antes que `max`, percent
    // quedaría en 0 y una tecla de subir pondría el brillo al 5 %
    FileView {
        id: max
        path: root.available ? root.device + "/max_brightness" : ""
        blockLoading: true
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
