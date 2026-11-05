// Título de la ventana activa. Cada pantalla muestra solo la suya y la isla
// desaparece si el workspace está vacío.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components

Island {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property HyprlandToplevel window: Hyprland.activeToplevel

    readonly property bool hasWindow: window !== null
        && window.workspace?.id === monitor?.activeWorkspace?.id
        && (monitor?.activeWorkspace?.toplevels.values.length ?? 0) > 0

    visible: hasWindow

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 360)
        elide: Text.ElideRight
        text: root.window?.title ?? ""
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
    }
}
