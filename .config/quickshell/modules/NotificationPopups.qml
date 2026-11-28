// Notification popups, top right (below the bar),
// on the focused screen.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    screen: Theme.focusedScreen
    visible: Notifs.popups.length > 0

    anchors {
        top: true
        right: true
    }
    // On the Overlay layer Hyprland doesn't keep the popups off the bar,
    // so they are placed below it by hand (if it's hidden, at the very top)
    margins {
        top: TopBar.belowBar
        right: Theme.gap
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    implicitWidth: 400   // card width
    implicitHeight: column.implicitHeight
    color: "transparent"

    Column {
        id: column
        width: parent.width
        spacing: Theme.gap

        Repeater {
            model: Notifs.popups.slice(0, 5) // at most 5 at a time

            NotificationCard {
                width: column.width
                popup: true
            }
        }
    }
}
