// Los popups de notificación, arriba a la derecha (debajo de la barra),
// en la pantalla que tenga el foco.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.popups.length > 0

    anchors {
        top: true
        right: true
    }
    // En la capa Overlay Hyprland no aparta los popups de la barra,
    // así que se dejan debajo a mano
    margins {
        top: Theme.barHeight + Theme.gap * 2
        right: Theme.gap
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    implicitWidth: 400
    implicitHeight: column.implicitHeight
    color: "transparent"

    Column {
        id: column
        width: parent.width
        spacing: Theme.gap

        Repeater {
            model: Notifs.popups.slice(0, 5) // como mucho 5 a la vez

            NotificationCard {
                popup: true
            }
        }
    }
}
