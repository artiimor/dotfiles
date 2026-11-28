// The bar of one screen. This is where you decide which modules go on each side.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules
import qs.services

PanelWindow {
    id: bar

    // Variants (in shell.qml) fills this with the right screen
    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    // The window sits against the edge so the defined background reaches the very
    // top; the old gap is now content margins
    implicitHeight: Theme.barHeight + Theme.gap
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"

    // Background: none by default, only the icons (light or dark depending on the
    // wallpaper, see TopBar). Double-clicking an empty spot of the bar
    // "defines" it: a flat, almost opaque background and a thin line below. Saved in
    // TopBar (survives restarts)
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.bgSolid, 0.95)
        opacity: TopBar.solidBackground ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.border
        }
    }

    // Behind the content: clicks on icons, workspaces and tray go to their
    // own MouseArea; only what lands on an empty spot reaches this one
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onDoubleClicked: TopBar.toggleBackground()
    }

    Item {
        anchors.fill: parent

        Item {
            id: content
            anchors.fill: parent
            anchors.topMargin: Theme.gap
            anchors.leftMargin: Theme.gap
            anchors.rightMargin: Theme.gap

            // Izquierda
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.gap

                Workspaces { screen: bar.modelData }
                Media {}
            }

            // Centro
            Center {
                anchors.centerIn: parent
            }

            // Derecha
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.gap

                // Hidden while the Status drawer covers it
                Tray {
                    opacity: status.drawerOpen ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                }
                Status { id: status }
            }
        }
    }
}
