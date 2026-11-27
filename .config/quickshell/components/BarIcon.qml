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
//
// Si icon es solo un glifo (sin letras ni números), se centra por su tinta y no
// por la caja de la fuente: los glifos de Nerd Font vienen de otra fuente (la de
// respaldo) y cada uno tiene sus márgenes, así unos quedaban altos o torcidos.
// Con cell > 0 el ancho es fijo (como mínimo cell): glifos de distinto ancho
// quedan a la misma distancia unos de otros.
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
    property int cell: 0
    property bool clickable: true   // false: sin la manita (solo tooltip o rueda)
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolledUp
    signal scrolledDown

    // Solo glifos: ni letras ni números (p. ej. "󰕾", "⏻" o "󰂯 󰕾")
    readonly property bool glyph: icon !== "" && !/[0-9A-Za-z\u00C0-\u024F]/.test(icon)

    implicitWidth: Math.max(cell, label.implicitWidth + padding * 2)
    implicitHeight: Theme.barHeight

    // Caja de la tinta del glifo (relativa a la línea base)
    TextMetrics {
        id: ink
        font: label.font
        text: root.glyph ? root.icon : ""
    }

    Text {
        id: label
        // Redondeado a píxeles enteros para que no salga borroso
        x: root.glyph ? Math.round((root.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x)
                      : Math.round((root.width - implicitWidth) / 2)
        y: root.glyph ? Math.round(root.height / 2 - baselineOffset - ink.tightBoundingRect.y - ink.tightBoundingRect.height / 2)
                      : Math.round((root.height - implicitHeight) / 2)
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
