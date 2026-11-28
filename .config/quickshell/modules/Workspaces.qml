// Hyprland workspaces of THIS screen, numbered 1..10 (in Hyprland they are
// id = monitor*10 + n, see wsFor in binds.lua). Click to go, wheel to
// move to the next/previous. Desktop-mode ones have the number in a
// box, like a small window.
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

    // (can't be called focus: Item's focus property would shadow it)
    function goTo(target) {
        Hypr.dispatch(`hl.dsp.focus({ workspace = "${target}" })`);
    }

    Repeater {
        // Special workspaces (scratchpad) have a negative id: out.
        // ScriptModel keeps the delegates of the ones that remain
        model: ScriptModel {
            values: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === root.screen.name)
        }

        Item {
            id: ws
            required property HyprlandWorkspace modelData
            // On the laptop (its screen is eDP-…), 11..20 (orphans of the
            // external monitor) show their real number
            readonly property int num: root.screen.name.startsWith("eDP") ? modelData.id : (modelData.id - 1) % 10 + 1
            readonly property bool active: modelData.id === root.monitor?.activeWorkspace?.id
            readonly property bool hovered: mouse.containsMouse
            readonly property bool desktop: DesktopMode.workspaces.includes(modelData.name)

            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Theme.barHeight - 8
            // Fixed width (at least): 1 and 3 aren't the same width and looked uneven
            implicitWidth: Math.max(24, label.implicitWidth + 14)

            // The active one has no pill: just a small line under the number
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
                // Centered and rounded to whole pixels (otherwise it's blurry)
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

    // The wheel works on the whole island, not only over a number
    WheelHandler {
        parent: root
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => root.goTo(e.angleDelta.y > 0 ? "m+1" : "m-1")
    }
}
