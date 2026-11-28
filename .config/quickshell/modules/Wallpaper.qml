// Wallpaper on every screen: replaces hyprpaper.
// The image is changed in Theme.qml (Theme.desktopWallpaper).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Variants {
    model: Quickshell.screens

    PanelWindow {
        required property ShellScreen modelData
        screen: modelData

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-wallpaper"
        color: Theme.bgSolid

        Image {
            anchors.fill: parent
            source: Theme.desktopWallpaper
            fillMode: Image.PreserveAspectCrop // like fit_mode = cover
            smooth: false // sharp pixels for the pixel art
            asynchronous: true
            // Load it at the screen's resolution, no more
            sourceSize.width: parent.width
            sourceSize.height: parent.height
        }
    }
}
