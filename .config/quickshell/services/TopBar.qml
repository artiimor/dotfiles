// Show or hide the top bar (Super+B), like in Omarchy. Hidden, it frees
// its space and windows use the full height. Not saved across restarts.
//
// Also the bar background: none by default, and double-clicking an
// empty spot "defines" it (flat background). This one is saved, in
// $XDG_STATE_HOME/quickshell-bar-background ("1" or "0").
//
// From outside:
//   qs ipc call bar toggle
//   qs ipc call bar background
//
// Without background, the bar colors (fg/muted/accent/border, used by the
// bar modules instead of Theme's) follow the wallpaper, not the theme,
// like in macOS: the brightness of the top strip of the
// wallpaper is measured (ffmpeg) and it's painted light or dark. With the background defined, the
// theme's.
//
// In Mac Mode the bar is macshell's: this does nothing.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool shown: true
    // Top margin of what shows below the bar (launcher, notifications)
    readonly property int belowBar: shown ? Theme.barHeight + Theme.gap * 2 : Theme.gap

    // Defined (flat) background or none
    property bool solidBackground: false

    // Is the top strip of the wallpaper dark? (luminance 0-255)
    property int wallpaperLuma: 0
    readonly property bool wallpaperDark: wallpaperLuma < 140

    readonly property color fg: solidBackground ? Theme.fg : wallpaperDark ? "#f5f5f7" : "#1d1d1f"
    readonly property color muted: solidBackground ? Theme.muted
        : wallpaperDark ? Theme.withAlpha("#f5f5f7", 0.6) : Theme.withAlpha("#1d1d1f", 0.55)
    // The theme accent, lightened or darkened if it wouldn't be readable on the background
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

    // Average of the top strip (4% of the height) reduced to one grey pixel
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
    // In Mac Mode this singleton is also created (the launcher uses belowBar),
    // but nobody uses the luminance there: ffmpeg isn't launched
    function measureLuma() {
        if (Theme.profileReady && !Theme.mac)
            luma.running = true;
    }
    Connections {
        target: Theme
        function onDesktopWallpaperChanged() { root.measureLuma(); }
        function onProfileReadyChanged() { root.measureLuma(); }
    }
    Component.onCompleted: measureLuma()

    function toggleBackground() {
        solidBackground = !solidBackground;
        bgFile.setText(solidBackground ? "1\n" : "0\n");
    }

    FileView {
        id: bgFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell-bar-background"
        printErrors: false // doesn't exist until the first double click
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
