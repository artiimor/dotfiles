// Un icono (o texto) clicable de la barra, con tooltip y rueda del ratón.
//
//   BarIcon {
//       icon: "󰕾"
//       color: Theme.accent
//       hoverColor: Theme.red        // opcional: color con el ratón encima
//       tooltip: I18n.tr("Volume %1%", 50)
//       onClicked: mouse => ...      // mouse.button dice qué botón
//       onScrolledUp: ...
//   }
import QtQuick
import Quickshell
import qs

Item {
    id: root

    property string icon
    property color color: Theme.fg
    property color hoverColor: color
    property string tooltip
    property int pixelSize: Theme.iconSize
    property bool italic: false
    property int padding: 10
    property bool clickable: true   // false: sin la manita (solo tooltip o rueda)
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
        textFormat: Text.PlainText   // p. ej. el título de la canción (Media) viene de fuera
        color: root.hovered ? root.hoverColor : root.color
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => root.clicked(m)
        onWheel: w => {
            if (w.angleDelta.y > 0)
                root.scrolledUp();
            else if (w.angleDelta.y < 0)
                root.scrolledDown();
        }
    }

    // Solo se crea con el ratón encima y texto (el retraso del Tooltip tapa la creación)
    LazyLoader {
        active: root.hovered && root.tooltip !== ""

        Tooltip {
            target: root
            text: root.tooltip
            show: true
        }
    }
}
