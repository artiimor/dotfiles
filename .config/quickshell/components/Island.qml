// An "island": each group of bar modules. It no longer has a frame (the bar
// has a gradient behind it for legibility); it only lays out its content in a row.
import QtQuick
import qs

Item {
    id: root

    default property alias content: row.data
    property int padding: 6
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
    }

    Row {
        id: row
        anchors.centerIn: parent
        height: parent.height
    }
}
