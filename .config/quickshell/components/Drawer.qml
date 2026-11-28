// Drawer: a row that slides out (from 0 to its width) while the mouse is on
// the fixed area of the module (its parent) or on the drawer itself.
// It's what "drawer" does in Waybar: the clock and the system arrow use it.
import QtQuick
import qs

Item {
    id: root

    readonly property bool open: hover.hovered || zoneHover.hovered
    // true: grows to the left (anchored on the right), the content comes out against the fixed edge
    property bool fromRight: false
    default property alias content: row.data

    implicitHeight: Theme.barHeight
    implicitWidth: open ? row.implicitWidth : 0
    clip: true
    opacity: open ? 1 : 0

    HoverHandler { id: hover }
    HoverHandler { id: zoneHover; parent: root.parent }

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.drawerAnim; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.drawerAnim }
    }

    Row {
        id: row
        anchors.right: root.fromRight ? parent.right : undefined
        height: parent.height
    }
}
