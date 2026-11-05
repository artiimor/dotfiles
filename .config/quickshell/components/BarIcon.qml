// Un icono (o texto) clicable de la barra, con tooltip y rueda del ratón.
//
//   BarIcon {
//       icon: "󰕾"
//       color: Theme.accent
//       tooltip: "Volumen 50%"
//       onClicked: mouse => ...      // mouse.button dice qué botón
//       onScrolledUp: ...
//   }
import QtQuick
import qs

Item {
    id: root

    property string icon
    property color color: Theme.fg
    property string tooltip
    property int pixelSize: Theme.iconSize
    property bool italic: false
    property int padding: 14
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolledUp
    signal scrolledDown

    implicitWidth: label.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon
        color: root.color
        font.family: Theme.font
        font.pixelSize: root.pixelSize
        font.bold: true
        font.italic: root.italic

        Behavior on color {
            ColorAnimation { duration: Theme.anim }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => root.clicked(m)
        onWheel: w => {
            if (w.angleDelta.y > 0)
                root.scrolledUp();
            else if (w.angleDelta.y < 0)
                root.scrolledDown();
        }
    }

    Tooltip {
        target: root
        text: root.tooltip
        show: root.hovered
    }
}
