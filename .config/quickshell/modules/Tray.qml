// System tray. Click: open the app · Right click: its menu
// (components/TrayMenu.qml).
// Hidden if there are no icons.
import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

Island {
    id: root

    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property SystemTrayItem modelData
            readonly property bool attention: modelData.status === Status.NeedsAttention

            // Same cell as the Status icons, so the spacing between icons is the same
            implicitWidth: Theme.iconCell
            implicitHeight: Theme.barHeight

            Rectangle {
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: 6
                color: trayItem.attention ? Theme.red : mouse.containsMouse ? Theme.surface : "transparent"
            }

            IconImage {
                anchors.centerIn: parent
                // A bit smaller than before: at 16 they looked bigger than the glyphs next
                // to them (even, so it stays on whole pixels inside the cell)
                implicitSize: 14
                source: trayItem.modelData.icon
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: m => {
                    const item = trayItem.modelData;
                    if (m.button === Qt.MiddleButton)
                        item.secondaryActivate();
                    else if (m.button === Qt.RightButton || item.onlyMenu) {
                        if (item.hasMenu)
                            menu.toggle();
                    } else
                        item.activate();
                }
                onWheel: w => trayItem.modelData.scroll(w.angleDelta.y, false)
            }

            TrayMenu {
                id: menu
                target: trayItem
                rootMenu: trayItem.modelData.menu
            }

            Tooltip {
                target: trayItem
                show: mouse.containsMouse && !menu.visible
                text: trayItem.modelData.tooltipTitle || trayItem.modelData.title
            }
        }
    }
}
