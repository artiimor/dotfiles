// Workspaces de Hyprland de ESTA pantalla, numerados 1..10 (en Hyprland son
// id = monitor*10 + n, ver wsFor en binds.lua). Clic para ir, rueda para
// pasar al siguiente/anterior. Los de modo escritorio llevan el número en un
// recuadro, como una ventanita.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

Island {
    id: root
    padding: 4
    spacing: 2

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    function focus(target) {
        // La config de Hyprland es Lua, así que dispatch usa sintaxis hl.dsp
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = "${target}" })`]);
    }

    Repeater {
        // Los workspaces especiales (scratchpad) tienen id negativo: fuera
        model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === root.screen.name)

        Item {
            id: ws
            required property HyprlandWorkspace modelData
            readonly property int num: (modelData.id - 1) % 10 + 1
            readonly property bool active: modelData.id === root.monitor?.activeWorkspace?.id
            readonly property bool hovered: mouse.containsMouse
            readonly property bool desktop: DesktopMode.workspaces.includes(modelData.name)
            readonly property color tint: Theme.wsColors[(num - 1) % Theme.wsColors.length]

            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Theme.barHeight - 8
            implicitWidth: label.implicitWidth + 18

            // El activo no lleva pastilla: solo una rayita debajo del número
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                height: 2
                radius: 1
                width: ws.active ? 14 : 0
                color: ws.modelData.urgent ? Theme.red : ws.tint

                Behavior on width {
                    NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                visible: ws.desktop
                anchors.centerIn: label
                width: label.implicitWidth + 10
                height: label.implicitHeight + 2
                radius: 4
                color: "transparent"
                border.width: 1.5
                border.color: label.color
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: ws.num
                color: ws.modelData.urgent ? Theme.red : ws.active || ws.hovered ? ws.tint : Qt.alpha(ws.tint, 0.45)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ws.modelData.activate()
            }
        }
    }

    // La rueda funciona en toda la isla, no solo encima de un número
    WheelHandler {
        parent: root
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => root.focus(e.angleDelta.y > 0 ? "m+1" : "m-1")
    }
}
