pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

ColumnLayout {
    id: bp
    implicitWidth: 270
    spacing: 8

    readonly property var dev: Sys.battery
    readonly property string stateText: {
        if (!dev) return "";
        switch (dev.state) {
        case UPowerDeviceState.Charging:
            return dev.timeToFull > 0 ? I18n.tr("Charging · %1 until full", Sys.duration(dev.timeToFull)) : I18n.tr("Charging");
        case UPowerDeviceState.FullyCharged: return I18n.tr("Fully Charged");
        case UPowerDeviceState.PendingCharge: return I18n.tr("Plugged in, not charging");
        case UPowerDeviceState.Discharging:
            return dev.timeToEmpty > 0 ? I18n.tr("On battery · %1 left", Sys.duration(dev.timeToEmpty)) : I18n.tr("On battery");
        default: return "";
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 4
        Text {
            Layout.fillWidth: true
            text: I18n.tr("Battery")
            color: Theme.text
            font.pointSize: 10.5
            font.weight: Font.DemiBold
        }
        Text {
            text: Math.round(Sys.batteryFraction * 100) + " %"
            color: Theme.text
            font.pointSize: 10.5
        }
    }
    Text {
        Layout.leftMargin: 4
        text: bp.stateText
        color: Theme.dim
        font.pointSize: 9
    }

    SectionLabel {
        Layout.leftMargin: 4
        Layout.topMargin: 4
        text: I18n.tr("Energy Mode")
    }
    // control segmentado
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 8
        color: Theme.tint(0.08)
        border.width: Theme.outlineWidth
        border.color: Theme.separator
        RowLayout {
            anchors.fill: parent
            anchors.margins: 2
            spacing: 2
            Repeater {
                model: [
                    { label: I18n.tr("Low Power"), p: PowerProfile.PowerSaver },
                    { label: I18n.tr("Balanced"), p: PowerProfile.Balanced },
                    { label: I18n.tr("Performance"), p: PowerProfile.Performance }
                ].filter(o => o.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                delegate: Rectangle {
                    id: seg
                    required property var modelData
                    readonly property bool sel: PowerProfiles.profile === modelData.p
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    radius: 6
                    color: sel ? Theme.tint(0.22) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: seg.modelData.label
                        color: Theme.text
                        font.pointSize: 8.5
                        font.weight: seg.sel ? Font.DemiBold : Font.Normal
                    }
                    MouseArea { anchors.fill: parent; onClicked: PowerProfiles.profile = seg.modelData.p }
                }
            }
        }
    }
}
