// Colors of the active theme: read from ~/.config/themes/current/theme.json
// ("ui" section). Change theme: Super+Ctrl+T or `wasdjy-theme <theme>`,
// which notifies with `qs ipc call theme reload` and everything is recolored at once.
// The fallback values below are Miami night's.
// Used from any file as Theme.accent, Theme.barHeight...
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    // "ui" section of the active theme's theme.json
    property var ui: ({})
    // "light": true in theme.json: light theme (e.g. the bar is more opaque)
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

    // Desktop profile (written by wasdjy-config): in "mac" and "mac-light" (Mac Mode
    // with a dark or light theme; with macshell installed) the windows from here that are
    // still used (launcher and its menus, OSD, polkit, dock) copy macshell's look
    // instead of the color theme.
    // No file: "mac" if macshell is present. "mac" without macshell = "default".
    // Watched because wasdjy-theme switches between "mac" and "mac-light" without restarting qs
    // (macLight changes at once). But mac (which bar and notifications exist)
    // keeps its start-up value: going from Mac Mode to normal or back, wasdjy-config
    // restarts qs, and if it changed earlier the bar and notification server from here
    // would appear while macshell is still alive
    FileView {
        id: profileFile
        path: Quickshell.env("HOME") + "/.local/state/desktop-profile"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (!root.profileChecked)
                root.startProfile = text().trim();
            root.profileChecked = true;
        }
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
    // The checks may finish after this singleton is created: until
    // profileReady is true it isn't known yet whether macshell is in charge (shell.qml waits
    // for it so it doesn't grab the notification server in Mac Mode)
    property bool profileChecked: false
    property bool macChecked: false
    readonly property bool profileReady: profileChecked && macChecked
    readonly property string profile: profileFile.loaded ? profileFile.text().trim() : ""
    property string startProfile: ""  // the profile at start-up ("" without file)
    readonly property bool mac: macshellFile.loaded && startProfile !== "default"
    readonly property bool macLight: mac && profile === "mac-light"

    // Increase contrast ("1" in ~/.local/state/increased-contrast; changed by
    // wasdjy-contrast): opaque backgrounds, marked borders and lighter muted text.
    // The script writes the file with rename: FileView watches the folder
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

    // The same color with another opacity: Theme.withAlpha(Theme.fg, 0.5)
    function withAlpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // One wheel step on a 0 to 1 bar (d: +0.05 per step up).
    // Volume can go above 1 (Pipewire allows it): above that, raising does
    // nothing and lowering subtracts d without jumping to 1
    function wheelStep(v: real, d: real): real {
        return d > 0 ? (v < 1 ? Math.min(1, v + d) : v) : Math.max(0, v + d);
    }

    // The focused screen (for windows that only show on one)
    readonly property ShellScreen focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]

    // mac / mac-light: macshell's colors (macshell/Theme.qml)
    readonly property color bgSolid: macLight ? "#f5f5f7" : mac ? "#28282b" : ui.bg ?? "#0d0b12"
    readonly property color bg: withAlpha(bgSolid, contrast ? 1 : mac ? 0.88 : 0.85) // translucent
    readonly property color surface: macLight ? Qt.rgba(0, 0, 0, 0.07) : mac ? Qt.rgba(1, 1, 1, 0.10) : ui.surface ?? "#1c1826"
    readonly property color fg: macLight ? "#1d1d1f" : mac ? "#f5f5f7" : ui.fg ?? "#f0eff1"
    // Con contraste, a medio camino hacia fg
    readonly property color muted: Qt.tint(macLight ? "#86868b" : mac ? "#98989d" : ui.muted ?? "#5d6088",
        withAlpha(fg, contrast ? 0.5 : 0))
    readonly property color accent: macLight ? "#007aff" : mac ? "#0a84ff" : ui.accent ?? "#848bbd"
    readonly property color accent2: mac ? accent : ui.accent2 ?? "#36f9f6"
    readonly property color accentDim: mac ? Qt.darker(accent, 1.35) : ui.accentDim ?? "#6b6789" // for borders and gradients
    // Text and symbols on the selected row / primary button
    readonly property color onAccent: mac ? "white" : bgSolid
    // Border of standalone windows (OSD, polkit): thin and grey in mac
    readonly property color frame: contrast ? withAlpha(fg, 0.75) : mac ? border : accentDim
    readonly property color red: ui.red ?? "#fe4450"
    readonly property color yellow: ui.yellow ?? "#fede5d"

    // Pastels: one color per function
    readonly property color pink: ui.pink ?? "#e89bd0"
    readonly property color cyan: ui.cyan ?? "#86d4dc"
    readonly property color peach: ui.peach ?? "#f2b8a0"
    readonly property color butter: ui.butter ?? "#f0d99a"
    readonly property color mint: ui.mint ?? "#9fdcc0"

    // Launcher background and its selected row
    readonly property color launcherBg: mac ? bg : ui.launcherBg ?? "#1c2030"
    readonly property color launcherSel: mac ? accent : ui.launcherSel ?? "#2a3045"

    // Thin border of the islands
    readonly property color borderBase: ui.border ?? "#b893ce"
    readonly property color border: contrast ? withAlpha(fg, 0.5) : macLight ? Qt.rgba(0, 0, 0, 0.12) : mac ? Qt.rgba(1, 1, 1, 0.12)
        : withAlpha(borderBase, 0.25)

    readonly property string font: mac ? "Noto Sans" : "Inter"
    readonly property int fontSize: 13
    readonly property int iconSize: 12
    readonly property int iconCell: 30 // fixed width of each bar icon (glyphs and tray)

    readonly property int barHeight: 26
    readonly property int gap: 8      // spacing between islands and bar margin
    readonly property int radius: mac ? 14 : 10
    readonly property int popupGap: 10 // spacing between the bar and its popups and tooltips

    // Wallpaper (also used, sharp and barely darkened, on the lock screen)
    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.config/backgrounds/wallpaper.jpg"
    // Desktop only: the theme's background (Super+Ctrl+B, wasdjy-background);
    // by default the meadow with all the pepes in color
    property string desktopWallpaper: "file://" + Quickshell.env("HOME") + "/.config/backgrounds/wallpaper-desktop.jpg"
    Process {
        id: backgroundProc
        command: [Quickshell.env("HOME") + "/.local/share/wasdjy/bin/wasdjy-background", "--path"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) root.desktopWallpaper = "file://" + text.trim()
        }
    }

    readonly property int anim: 250   // animation duration (ms)
    readonly property int drawerAnim: 400
}
