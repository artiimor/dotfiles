import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

// Bar "System" popup: what the normal bar keeps in its drawer (memory,
// temperature, power profile and shutdown), in a macOS-style menu.
ColumnLayout {
    id: sp
    signal openProfiles()
    signal openPower()

    implicitWidth: 240
    spacing: 8

    readonly property bool hot: Sys.temp >= Sys.tempCritical
    readonly property string profileName: PowerProfiles.profile === PowerProfile.Performance ? I18n.tr("Performance")
        : PowerProfiles.profile === PowerProfile.PowerSaver ? I18n.tr("Low Power") : I18n.tr("Balanced")

    Text {
        Layout.leftMargin: 4
        Layout.topMargin: 2
        text: I18n.tr("System")
        color: Theme.text
        font.pointSize: 10.5
        font.weight: Font.DemiBold
    }

    Tile {
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: I18n.tr("Memory"); color: Theme.text; font.pointSize: 9.5 }
            Text {
                text: Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GiB"
                color: Theme.dim
                font.pointSize: 9
            }
        }
        // usage bar
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
            Text { Layout.fillWidth: true; text: I18n.tr("CPU Temperature"); color: Theme.text; font.pointSize: 9.5 }
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
            text: I18n.tr("Power Mode: %1", sp.profileName)
            submenu: true
            onTriggered: sp.openProfiles()
        }
        MenuRow {
            Layout.fillWidth: true
            text: I18n.tr("Power…")
            onTriggered: sp.openPower()
        }
    }
}
