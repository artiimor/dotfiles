// A clickable bar icon (or text), with tooltip and mouse wheel.
//
//   BarIcon {
//       icon: "󰕾"
//       color: Theme.accent
//       hoverColor: Theme.red        // optional: color on mouse hover
//       tooltip: I18n.tr("Volume %1%", 50)
//       onClicked: mouse => ...      // mouse.button tells which button
//       onScrolledUp: ...
//   }
//
// If icon is only a glyph (no letters or numbers), it is centered by its ink and not
// by the font box: Nerd Font glyphs come from another font (the
// fallback one) and each has its own margins, so some ended up high or crooked.
// With cell > 0 the width is fixed (at least cell): glyphs of different widths
// end up at the same distance from each other.
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
    property bool clickable: true   // false: no hand cursor (only tooltip or wheel)
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolledUp
    signal scrolledDown

    // Glyphs only: no letters or numbers (e.g. "󰕾", "⏻" or "󰂯 󰕾")
    readonly property bool glyph: icon !== "" && !/[0-9A-Za-z\u00C0-\u024F]/.test(icon)

    implicitWidth: Math.max(cell, label.implicitWidth + padding * 2)
    implicitHeight: Theme.barHeight

    // Ink box of the glyph (relative to the baseline)
    TextMetrics {
        id: ink
        font: label.font
        text: root.glyph ? root.icon : ""
    }

    Text {
        id: label
        // Rounded to whole pixels so it doesn't come out blurry
        x: root.glyph ? Math.round((root.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x)
                      : Math.round((root.width - implicitWidth) / 2)
        y: root.glyph ? Math.round(root.height / 2 - baselineOffset - ink.tightBoundingRect.y - ink.tightBoundingRect.height / 2)
                      : Math.round((root.height - implicitHeight) / 2)
        text: root.icon
        textFormat: Text.PlainText   // e.g. the song title (Media) comes from outside
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

    // Only created with the mouse over it and text (the Tooltip delay hides the creation)
    LazyLoader {
        active: root.hovered && root.tooltip !== ""

        Tooltip {
            target: root
            text: root.tooltip
            show: true
        }
    }
}
