// Fondo de pantalla en todas las pantallas: sustituye a hyprpaper.
// La imagen se cambia en Theme.qml (Theme.desktopWallpaper).
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
            fillMode: Image.PreserveAspectCrop // como fit_mode = cover
            smooth: false // píxeles nítidos para el pixel art
            asynchronous: true
            // Cargarla a la resolución de la pantalla, no más
            sourceSize.width: parent.width
            sourceSize.height: parent.height
        }
    }
}
