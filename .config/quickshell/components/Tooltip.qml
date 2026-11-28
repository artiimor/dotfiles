// Tooltip that appears below `target` (or above with `above`) when `show` is true.
// If you want more than text, add children and leave `text` empty.
import QtQuick
import Quickshell
import qs

PopupWindow {
    id: root

    required property Item target
    property string text
    property bool show: false
    property bool above: false
    default property alias content: col.data

    // Small delay so it doesn't flicker when the mouse just passes by.
    // Counts from when there is something to show (the first child of col is the text).
    readonly property bool _wanted: show && (text !== "" || col.children.length > 1)
    property bool _ready: false
    Timer {
        interval: 350
        running: root._wanted
        onTriggered: root._ready = true
    }
    on_WantedChanged: if (!_wanted) _ready = false

    visible: _ready

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.y: above ? -Theme.popupGap : 0
    anchor.rect.height: target.height + (above ? 0 : Theme.popupGap)
    anchor.edges: above ? Edges.Top : Edges.Bottom
    anchor.gravity: above ? Edges.Top : Edges.Bottom

    implicitWidth: col.implicitWidth + 24
    implicitHeight: col.implicitHeight + 16
    color: "transparent"

    PopupBox {
        anchors.fill: parent

        Column {
            id: col
            x: 12
            y: 8

            Text {
                visible: root.text !== ""
                text: root.text
                textFormat: Text.PlainText   // titles, networks, devices: they come from outside
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }
    }
}
