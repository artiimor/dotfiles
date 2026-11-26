import QtQuick

// Botón con texto (píldora). Por defecto se ajusta al texto; si se le da un
// ancho mayor, el texto va centrado y se recorta si no cabe.
Rectangle {
    id: b
    property string text: ""
    property bool danger: false
    property real pointSize: 9.5
    signal tapped()

    implicitWidth: label.implicitWidth + 22
    implicitHeight: 24
    radius: 6
    color: mouse.containsMouse ? Theme.buttonHover : Theme.button
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, b.width - 12)
        elide: Text.ElideRight
        text: b.text
        color: b.danger ? "#ff6961" : Theme.text
        font.pointSize: b.pointSize
    }
    // MouseArea y no TapHandler: así el clic no llega también a lo que hay debajo
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: b.tapped() }
}
