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

    // (no se puede llamar focus: lo taparía la propiedad focus de Item)
    function goTo(target) {
        Hypr.dispatch(`hl.dsp.focus({ workspace = "${target}" })`);
    }

    Repeater {
        // Los workspaces especiales (scratchpad) tienen id negativo: fuera.
        // ScriptModel conserva los delegados de los que siguen
        model: ScriptModel {
            values: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === root.screen.name)
        }

        Item {
            id: ws
            required property HyprlandWorkspace modelData
            // En el portátil (su pantalla es eDP-…), los 11..20 (huérfanos del
            // monitor externo) muestran su número real
            readonly property int num: root.screen.name.startsWith("eDP") ? modelData.id : (modelData.id - 1) % 10 + 1
            readonly property bool active: modelData.id === root.monitor?.activeWorkspace?.id
            readonly property bool hovered: mouse.containsMouse
            readonly property bool desktop: DesktopMode.workspaces.includes(modelData.name)

            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Theme.barHeight - 8
            // Ancho fijo (como mínimo): el 1 y el 3 no miden lo mismo y quedaban desiguales
            implicitWidth: Math.max(24, label.implicitWidth + 14)

            // El activo no lleva pastilla: solo una rayita debajo del número
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                height: 2
                radius: 1
                width: ws.active ? 14 : 0
                color: ws.modelData.urgent ? Theme.red : TopBar.accent

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
                // Centrado y redondeado a píxeles enteros (si no, sale borroso)
                x: Math.round((ws.width - implicitWidth) / 2)
                y: Math.round((ws.height - implicitHeight) / 2)
                text: ws.num
                color: ws.modelData.urgent ? Theme.red : ws.active ? TopBar.accent : ws.hovered ? TopBar.fg : TopBar.muted
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
        onWheel: e => root.goTo(e.angleDelta.y > 0 ? "m+1" : "m-1")
    }
}
