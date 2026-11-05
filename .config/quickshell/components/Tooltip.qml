// Tooltip que aparece debajo de `target` (o encima con `above`) cuando `show` es true.
// Si quieres algo más que texto, mete hijos y deja `text` vacío.
import QtQuick
import Quickshell
import qs

PopupWindow {
    id: root

    required property Item target
    property string text
    property bool show: false
    property bool above: false
    default property alias content: extra.data

    // Pequeño retraso para que no parpadee al pasar el ratón de largo
    property bool _ready: false
    Timer {
        interval: 350
        running: root.show
        onTriggered: root._ready = true
    }
    onShowChanged: if (!show) _ready = false

    visible: _ready && (text !== "" || extra.children.length > 0)

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.y: above ? -10 : 0
    anchor.rect.height: target.height + (above ? 0 : 10)
    anchor.edges: above ? Edges.Top : Edges.Bottom
    anchor.gravity: above ? Edges.Top : Edges.Bottom

    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight
    color: "transparent"

    Rectangle {
        id: box
        implicitWidth: Math.max(label.implicitWidth, extra.childrenRect.width) + 24
        implicitHeight: (label.visible ? label.implicitHeight : 0) + extra.childrenRect.height + 16
        radius: Theme.radius
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.accentDim

        Text {
            id: label
            visible: root.text !== ""
            x: 12
            y: 8
            text: root.text
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        Item {
            id: extra
            x: 12
            y: 8
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
