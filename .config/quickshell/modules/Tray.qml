// Bandeja del sistema. Clic: abrir la app · Clic derecho: su menú
// (components/TrayMenu.qml).
// Se oculta si no hay ningún icono.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

Island {
    id: root
    padding: 6
    spacing: 4


    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property SystemTrayItem modelData
            readonly property bool attention: modelData.status === Status.NeedsAttention

            implicitWidth: 26
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
                implicitSize: 16
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
                            menu.visible ? menu.close() : menu.open();
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
