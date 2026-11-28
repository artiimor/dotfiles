import QtQuick

// macOS-style switch. The size is changed with implicitWidth/implicitHeight:
// the knob and the radius come from the height.
Rectangle {
    id: sw
    property bool on: false
    signal toggled()

    implicitWidth: 38; implicitHeight: 22
    radius: height / 2
    color: on ? Theme.accent : Theme.tint(0.2)
    border.width: on ? 0 : Theme.outlineWidth
    border.color: Theme.separator
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
        width: sw.height - 4; height: width; radius: width / 2
        y: 2
        x: sw.on ? sw.width - width - 2 : 2
        color: "white"
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; onClicked: sw.toggled() }
}
