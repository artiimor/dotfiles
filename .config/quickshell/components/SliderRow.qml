// Icono + barra deslizante + porcentaje (volumen, brillo...).
//   SliderRow {
//       icon: "󰕾"
//       value: 0.5                  // 0–1
//       onMoved: v => ...
//       onIconClicked: ...          // p. ej. silenciar
//   }
import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    id: root

    property string icon
    property color iconColor: Theme.accent
    property string tooltip
    property real value: 0
    // false: la barra se ve apagada (p. ej. silenciado), pero sigue respondiendo
    property bool active: true

    signal moved(real value)
    signal iconClicked

    spacing: 10

    BarIcon {
        implicitHeight: 24
        padding: 4
        pixelSize: 15
        icon: root.icon
        color: root.iconColor
        tooltip: root.tooltip
        onClicked: root.iconClicked()
    }
    Slider {
        Layout.fillWidth: true
        value: root.value
        enabled: root.active
        onMoved: v => root.moved(v)
    }
    Text {
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: 12
        font.bold: true
    }
}
