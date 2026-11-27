// Colores del tema activo: se leen de ~/.config/themes/current/theme.json
// (sección "ui"). Cambiar de tema: Super+Ctrl+T o `~/.config/themes/theme-set <tema>`,
// que avisa con `qs ipc call theme reload` y todo se recolorea al momento.
// Los valores de respaldo de abajo son los de Miami night.
// Se usa desde cualquier archivo como Theme.accent, Theme.barHeight...
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
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
    // Sin archivo: "mac" si está macshell. "mac" sin macshell = "default".
    FileView {
        id: profileFile
        path: Quickshell.env("HOME") + "/.local/state/desktop-profile"
        blockLoading: true
        printErrors: false
        onLoaded: root.profileChecked = true
        onLoadFailed: root.profileChecked = true
    }
    FileView {
        id: macshellFile
        path: Quickshell.env("HOME") + "/.config/quickshell/macshell/shell.qml"
        blockLoading: true
        printErrors: false
        onLoaded: root.macChecked = true
        onLoadFailed: root.macChecked = true
    }
    // Las comprobaciones pueden acabar después de crearse este singleton: hasta que
    // profileReady sea true no se sabe aún si manda macshell (shell.qml lo espera
    // para no quedarse con el servidor de notificaciones en Modo Mac)
    property bool profileChecked: false
    property bool macChecked: false
    readonly property bool profileReady: profileChecked && macChecked
    readonly property string profile: profileFile.loaded ? profileFile.text().trim() : ""
    readonly property bool mac: macshellFile.loaded && profile !== "default"
    readonly property bool macLight: mac && profile === "mac-light"

    // Aumentar contraste ("1" en ~/.local/state/increased-contrast; lo cambia
    // themes/contrast-set): fondos opacos, bordes marcados y texto apagado más claro.
    // El script escribe el archivo con rename: FileView vigila la carpeta
    FileView {
        id: contrastFile
        path: Quickshell.env("HOME") + "/.local/state/increased-contrast"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property bool contrast: contrastFile.loaded && contrastFile.text().trim() === "1"

    IpcHandler {
        target: "theme"
        function reload(): void {
            themeFile.reload();
            backgroundProc.running = true;
        }
    }

    // El mismo color con otra opacidad: Theme.withAlpha(Theme.fg, 0.5)
    function withAlpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Un paso de rueda en una barra de 0 a 1 (d: +0.05 por paso hacia arriba).
    // El volumen puede pasar de 1 (Pipewire lo permite): por encima, subir no hace
    // nada y bajar quita d sin saltar a 1
    function wheelStep(v: real, d: real): real {
        return d > 0 ? (v < 1 ? Math.min(1, v + d) : v) : Math.max(0, v + d);
    }

    // La pantalla con el foco (para las ventanas que solo salen en una)
    readonly property ShellScreen focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]

    // mac / mac-light: los colores de macshell (macshell/Theme.qml)
    readonly property color bgSolid: macLight ? "#f5f5f7" : mac ? "#28282b" : ui.bg ?? "#0d0b12"
    readonly property color bg: withAlpha(bgSolid, contrast ? 1 : mac ? 0.88 : 0.85) // translúcido
    readonly property color surface: macLight ? Qt.rgba(0, 0, 0, 0.07) : mac ? Qt.rgba(1, 1, 1, 0.10) : ui.surface ?? "#1c1826"
    readonly property color fg: macLight ? "#1d1d1f" : mac ? "#f5f5f7" : ui.fg ?? "#f0eff1"
    // Con contraste, a medio camino hacia fg
    readonly property color muted: Qt.tint(macLight ? "#86868b" : mac ? "#98989d" : ui.muted ?? "#5d6088",
        withAlpha(fg, contrast ? 0.5 : 0))
    readonly property color accent: macLight ? "#007aff" : mac ? "#0a84ff" : ui.accent ?? "#848bbd"
    readonly property color accent2: mac ? accent : ui.accent2 ?? "#36f9f6"
    readonly property color accentDim: mac ? Qt.darker(accent, 1.35) : ui.accentDim ?? "#6b6789" // para bordes y degradados
    // Texto y símbolos sobre la fila elegida / botón principal
    readonly property color onAccent: mac ? "white" : bgSolid
    // Borde de las ventanas sueltas (OSD, polkit): fino y gris en mac
    readonly property color frame: contrast ? withAlpha(fg, 0.75) : mac ? border : accentDim
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

    // Borde fino de las islas
    readonly property color borderBase: ui.border ?? "#b893ce"
    readonly property color border: contrast ? withAlpha(fg, 0.5) : macLight ? Qt.rgba(0, 0, 0, 0.12) : mac ? Qt.rgba(1, 1, 1, 0.12)
        : withAlpha(borderBase, 0.25)

    readonly property string font: mac ? "Noto Sans" : "Inter"
    readonly property int fontSize: 13
    readonly property int iconSize: 12
    readonly property int iconCell: 30 // ancho fijo de cada icono de la barra (glifos y bandeja)

    readonly property int barHeight: 26
    readonly property int gap: 8      // separación entre islas y margen de la barra
    readonly property int radius: mac ? 14 : 10
    readonly property int popupGap: 10 // separación entre la barra y sus popups y tooltips

    // Fondo de pantalla (también se usa, nítido y apenas oscurecido, en la pantalla de bloqueo)
    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.config/backgrounds/wallpaper.jpg"
    // Solo el escritorio: el fondo del tema (Super+Ctrl+B, themes/background-set);
    // por defecto el prado con todos los pepes en color
    property string desktopWallpaper: "file://" + Quickshell.env("HOME") + "/.config/backgrounds/wallpaper-desktop.jpg"
    Process {
        id: backgroundProc
        command: [Quickshell.env("HOME") + "/.config/themes/background-set", "--path"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) root.desktopWallpaper = "file://" + text.trim()
        }
    }

    readonly property int anim: 250   // duración de las animaciones (ms)
    readonly property int drawerAnim: 400
}
