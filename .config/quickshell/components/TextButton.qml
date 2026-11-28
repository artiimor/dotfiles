// Button with text (panels, dialogs, notification actions).
//
//   TextButton {
//       text: I18n.tr("Clear")
//       hoverColor: Theme.red        // background on mouse hover (not primary)
//       onClicked: ...
//   }
// primary: true is the main button (accent background). The rest is changed
// like in any Rectangle (implicitHeight, color, border...) and the text
// with font and textColor.
import QtQuick
import qs

Rectangle {
    id: root

    property alias text: label.text
    property alias font: label.font
    property alias textColor: label.color
    property bool primary: false
    property color hoverColor: Theme.accentDim
    property int padding: 20
    readonly property bool hovered: mouse.containsMouse
    signal clicked

    implicitWidth: label.implicitWidth + padding
    implicitHeight: 28
    radius: 7
    color: primary ? (Theme.mac ? (hovered ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
                                : (hovered ? Theme.accent : Theme.accentDim))
        : (hovered ? hoverColor : Theme.surface)

    Behavior on color {
        ColorAnimation { duration: Theme.anim }
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: root.primary ? Theme.onAccent : Theme.fg
        font.family: Theme.font
        font.pixelSize: 12
        font.bold: true
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
