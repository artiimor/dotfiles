// Colores del tema activo: se leen de ~/.config/themes/current/theme.json
// (sección "ui"). Cambiar de tema: Super+Ctrl+T o `~/.config/themes/theme-set <tema>`,
// que avisa con `qs ipc call theme reload` y todo se recolorea al momento.
// Los valores de respaldo de abajo son los de Miami night.
// Se usa desde cualquier archivo como Theme.accent, Theme.barHeight...
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Sección "ui" del theme.json del tema activo
    property var ui: ({})

    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/themes/current/theme.json"
        blockLoading: true
        onLoaded: {
            try {
                root.ui = JSON.parse(text()).ui ?? {};
            } catch (e) {
                console.warn("Theme: theme.json no válido:", e);
            }
        }
    }

    IpcHandler {
        target: "theme"
        function reload(): void { themeFile.reload(); }
    }

    readonly property color bgSolid: ui.bg ?? "#0d0b12"
    readonly property color bg: Qt.rgba(bgSolid.r, bgSolid.g, bgSolid.b, 0.85) // translúcido
    readonly property color surface: ui.surface ?? "#1c1826"
    readonly property color fg: ui.fg ?? "#f0eff1"
    readonly property color muted: ui.muted ?? "#5d6088"
    readonly property color accent: ui.accent ?? "#848bbd"
    readonly property color accent2: ui.accent2 ?? "#36f9f6"
    readonly property color accentDim: ui.accentDim ?? "#6b6789" // para bordes y degradados
    readonly property color ok: ui.ok ?? "#72f1b8"               // solo para estados (cargando...)
    readonly property color red: ui.red ?? "#fe4450"
    readonly property color yellow: ui.yellow ?? "#fede5d"

    // Pasteles: un color por función
    readonly property color pink: ui.pink ?? "#e89bd0"
    readonly property color cyan: ui.cyan ?? "#86d4dc"
    readonly property color peach: ui.peach ?? "#f2b8a0"
    readonly property color butter: ui.butter ?? "#f0d99a"
    readonly property color mint: ui.mint ?? "#9fdcc0"

    // Fondo del lanzador y de su fila elegida
    readonly property color launcherBg: ui.launcherBg ?? "#1c2030"
    readonly property color launcherSel: ui.launcherSel ?? "#2a3045"

    // Cada workspace tiene su color (el 6 vuelve a empezar)
    readonly property var wsColors: [accent, pink, cyan, peach, butter, mint]

    // Borde fino de las islas
    readonly property color borderBase: ui.border ?? "#b893ce"
    readonly property color border: Qt.rgba(borderBase.r, borderBase.g, borderBase.b, 0.25)

    readonly property string font: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 13
    readonly property int iconSize: 12

    readonly property int barHeight: 34
    readonly property int gap: 8      // separación entre islas y margen de la barra
    readonly property int radius: 10

    // Fondo de pantalla (también se usa, desenfocado, en la pantalla de bloqueo)
    readonly property string wallpaper: "file:///home/morci/.config/backgrounds/wallpaper.jpg"
    // Solo el escritorio: Pepe en color con sol (backgrounds/pepe_sol.py)
    readonly property string desktopWallpaper: "file:///home/morci/.config/backgrounds/wallpaper-desktop.jpg"

    readonly property int anim: 250   // duración de las animaciones (ms)
    readonly property int drawerAnim: 400
}
