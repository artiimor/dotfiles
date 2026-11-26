import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

// Popup "System" de la barra: lo que la barra normal guarda en su cajón (memoria,
// temperatura, perfil de energía y apagado), en un menú al estilo de macOS.
ColumnLayout {
    id: sp
    signal openProfiles()
    signal openPower()

    implicitWidth: 240
    spacing: 8

    readonly property bool hot: Sys.temp >= Sys.tempCritical
    readonly property string profileName: PowerProfiles.profile === PowerProfile.Performance ? "Performance"
        : PowerProfiles.profile === PowerProfile.PowerSaver ? "Low Power" : "Balanced"

    Text {
        Layout.leftMargin: 4
        Layout.topMargin: 2
        text: "System"
        color: Theme.text
        font.pointSize: 10.5
        font.weight: Font.DemiBold
    }

    Tile {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Memory"; color: Theme.text; font.pointSize: 9.5 }
            Text {
                text: Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GiB"
                color: Theme.dim
                font.pointSize: 9
            }
        }
        // barra de uso
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.tint(0.14)
            Rectangle {
                width: parent.width * (Sys.memTotal > 0 ? Math.min(1, Sys.memUsed / Sys.memTotal) : 0)
                height: parent.height
                radius: 3
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Text { Layout.fillWidth: true; text: "CPU Temperature"; color: Theme.text; font.pointSize: 9.5 }
            Text {
                text: Sys.temp + " °C"
                color: sp.hot ? Theme.red : Theme.dim
                font.pointSize: 9
                font.weight: sp.hot ? Font.DemiBold : Font.Normal
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        MenuRow {
            Layout.fillWidth: true
            text: "Power Mode: " + sp.profileName
            submenu: true
            onTriggered: sp.openProfiles()
        }
        MenuRow {
            Layout.fillWidth: true
            text: "Power…"
            onTriggered: sp.openPower()
        }
    }
}
