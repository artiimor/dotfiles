import QtQuick
import QtQuick.Layouts

// Menú de Pantalla de la barra (como el de macOS): brillo y Night Shift.
ColumnLayout {
    implicitWidth: 240
    spacing: 8

    Text {
        Layout.leftMargin: 4
        Layout.topMargin: 2
        text: "Display"
        color: Theme.text
        font.pointSize: 10.5
        font.weight: Font.DemiBold
    }
    Slider {
        Layout.fillWidth: true
        icon: "sun"
        value: Sys.brightness
        onMoved: v => Sys.setBrightness(v)
    }
    Divider { Layout.topMargin: 2 }
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 2
        Text {
            Layout.fillWidth: true
            text: "Night Shift"
            color: Sys.nightState === "unavailable" ? Theme.dim : Theme.text
            font.pointSize: 9.5
        }
        Switch {
            implicitWidth: 32; implicitHeight: 18
            on: Sys.nightOn
            opacity: Sys.nightState === "unavailable" ? 0.4 : 1
            onToggled: Sys.toggleNight()
        }
    }
}
