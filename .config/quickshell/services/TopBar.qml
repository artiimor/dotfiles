// Mostrar u ocultar la barra de arriba (Super+B), como en Omarchy. Oculta, deja
// libre su hueco y las ventanas usan toda la altura. No se guarda al reiniciar.
//
// También el fondo de la barra: por defecto no tiene, y con doble clic en un
// hueco vacío se "define" (fondo liso). Esto sí se guarda, en
// $XDG_STATE_HOME/quickshell-bar-background ("1" o "0").
//
// Desde fuera:
//   qs ipc call bar toggle
//   qs ipc call bar background
//
// Sin fondo, los colores de la barra (fg/muted/accent/border, que usan los
// módulos de la barra en vez de los de Theme) no siguen al tema sino al fondo
// de pantalla, como en macOS: se mira lo clara que es la franja de arriba del
// wallpaper (ffmpeg) y se pinta en claro u oscuro. Con el fondo definido, los
// del tema.
//
// En el Modo Mac la barra es la de macshell: aquí no hace nada.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool shown: true
    // Margen de arriba de lo que sale debajo de la barra (lanzador, notificaciones)
    readonly property int belowBar: shown ? Theme.barHeight + Theme.gap * 2 : Theme.gap

    // Fondo definido (liso) o ninguno
    property bool solidBackground: false

    // ¿La franja de arriba del fondo de pantalla es oscura? (luminancia 0-255)
    property int wallpaperLuma: 0
    readonly property bool wallpaperDark: wallpaperLuma < 140

    readonly property color fg: solidBackground ? Theme.fg : wallpaperDark ? "#f5f5f7" : "#1d1d1f"
    readonly property color muted: solidBackground ? Theme.muted
        : wallpaperDark ? Theme.withAlpha("#f5f5f7", 0.6) : Theme.withAlpha("#1d1d1f", 0.55)
    // El acento del tema, aclarado u oscurecido si no se leería sobre el fondo
    readonly property color accent: {
        if (solidBackground)
            return Theme.accent;
        const l = Theme.accent.hslLightness;
        if (wallpaperDark && l < 0.65)
            return Qt.hsla(Theme.accent.hslHue, Theme.accent.hslSaturation, 0.72, 1);
        if (!wallpaperDark && l > 0.45)
            return Qt.hsla(Theme.accent.hslHue, Theme.accent.hslSaturation, 0.38, 1);
        return Theme.accent;
    }
    readonly property color border: solidBackground ? Theme.border : Theme.withAlpha(fg, 0.3)

    // Media de la franja de arriba (4% de alto) reducida a un píxel gris
    Process {
        id: luma
        command: ["sh", "-c", "ffmpeg -v error -i \"$1\" -vf 'crop=iw:ih*0.04:0:0,scale=1:1,format=gray' -frames:v 1 -f rawvideo - | od -An -tu1", "sh",
            Theme.desktopWallpaper.replace(/^file:\/\//, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v))
                    root.wallpaperLuma = v;
            }
        }
    }
    Connections {
        target: Theme
        function onDesktopWallpaperChanged() { luma.running = true; }
    }
    Component.onCompleted: luma.running = true

    function toggleBackground() {
        solidBackground = !solidBackground;
        bgFile.setText(solidBackground ? "1\n" : "0\n");
    }

    FileView {
        id: bgFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell-bar-background"
        printErrors: false // no existe hasta el primer doble clic
        onLoaded: root.solidBackground = text().trim() === "1"
    }

    IpcHandler {
        target: "bar"
        function toggle(): void {
            if (!Theme.mac)
                root.shown = !root.shown;
        }
        function background(): void {
            if (!Theme.mac)
                root.toggleBackground();
        }
    }
}
