import QtQuick

// Button with text (pill). By default it fits the text; if given a
// larger width, the text is centered and elided if it doesn't fit.
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
    border.width: Theme.outlineWidth
    border.color: Theme.separator
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, b.width - 12)
        elide: Text.ElideRight
        text: b.text
        color: b.danger ? "#ff6961" : Theme.text
        font.pointSize: b.pointSize
    }
    // MouseArea and not TapHandler: this way the click doesn't also reach what's underneath
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: b.tapped() }
}
