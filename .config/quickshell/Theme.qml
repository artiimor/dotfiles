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
    // "light": true en theme.json: tema claro (p. ej. la barra va más opaca)
    property bool themeLight: false

    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/themes/current/theme.json"
        blockLoading: true
        onLoaded: {
            try {
                const t = JSON.parse(text());
                root.ui = t.ui ?? {};
                root.themeLight = !!t.light;
            } catch (e) {
                console.warn("Theme: theme.json no válido:", e);
            }
        }
    }

    // Perfil del escritorio (lo escribe config-set, que reinicia qs al cambiarlo):
    // en "mac" y "mac-light" (Modo Mac con un tema oscuro o claro; con macshell
    // instalado) las ventanas de aquí que se siguen usando (lanzador y sus menús,
    // OSD, polkit, dock) copian el aspecto de macshell en vez del tema de colores
    FileView {
        id: profileFile
        path: Quickshell.env("HOME") + "/.local/state/desktop-profile"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: macshellFile
        path: Quickshell.env("HOME") + "/.config/quickshell/macshell/shell.qml"
        blockLoading: true
        printErrors: false
    }
    readonly property string profile: profileFile.loaded ? profileFile.text().trim() : ""
    readonly property bool mac: macshellFile.loaded && profile !== "default" // igual que shell.qml
    readonly property bool macLight: mac && profile === "mac-light"

    IpcHandler {
        target: "theme"
        function reload(): void { themeFile.reload(); }
    }

    // mac / mac-light: los colores de macshell (Theme.qml del repo plasma-mac)
    readonly property color bgSolid: macLight ? "#f5f5f7" : mac ? "#28282b" : ui.bg ?? "#0d0b12"
    readonly property color bg: Qt.rgba(bgSolid.r, bgSolid.g, bgSolid.b, mac ? 0.88 : 0.85) // translúcido
    readonly property color surface: macLight ? Qt.rgba(0, 0, 0, 0.07) : mac ? Qt.rgba(1, 1, 1, 0.10) : ui.surface ?? "#1c1826"
    readonly property color fg: macLight ? "#1d1d1f" : mac ? "#f5f5f7" : ui.fg ?? "#f0eff1"
    readonly property color muted: macLight ? "#86868b" : mac ? "#98989d" : ui.muted ?? "#5d6088"
    readonly property color accent: macLight ? "#007aff" : mac ? "#0a84ff" : ui.accent ?? "#848bbd"
    readonly property color accent2: mac ? accent : ui.accent2 ?? "#36f9f6"
    readonly property color accentDim: mac ? Qt.darker(accent, 1.35) : ui.accentDim ?? "#6b6789" // para bordes y degradados
    // Texto y símbolos sobre la fila elegida / botón principal
    readonly property color onAccent: mac ? "white" : bgSolid
    // Borde de las ventanas sueltas (OSD, polkit): fino y gris en mac
    readonly property color frame: mac ? border : accentDim
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
    readonly property color launcherBg: mac ? bg : ui.launcherBg ?? "#1c2030"
    readonly property color launcherSel: mac ? accent : ui.launcherSel ?? "#2a3045"

    // Cada workspace tiene su color (el 6 vuelve a empezar)
    readonly property var wsColors: [accent, pink, cyan, peach, butter, mint]

    // Borde fino de las islas
    readonly property color borderBase: ui.border ?? "#b893ce"
    readonly property color border: macLight ? Qt.rgba(0, 0, 0, 0.12) : mac ? Qt.rgba(1, 1, 1, 0.12)
        : Qt.rgba(borderBase.r, borderBase.g, borderBase.b, 0.25)

    readonly property string font: mac ? "Noto Sans" : "Inter"
    readonly property int fontSize: 13
    readonly property int iconSize: 12

    readonly property int barHeight: 26
    readonly property int gap: 8      // separación entre islas y margen de la barra
    readonly property int radius: mac ? 14 : 10

    // Fondo de pantalla (también se usa, desenfocado, en la pantalla de bloqueo)
    readonly property string wallpaper: "file:///home/morci/.config/backgrounds/wallpaper.jpg"
    // Solo el escritorio: el prado con todos los pepes en color
    readonly property string desktopWallpaper: "file:///home/morci/.config/backgrounds/wallpaper-desktop.jpg"

    readonly property int anim: 250   // duración de las animaciones (ms)
    readonly property int drawerAnim: 400
}
