pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Bar Sound menu (like macOS's): volume and audio output.
// Everything goes against Pipewire, the same state used by the OSD and the normal bar.
ColumnLayout {
    id: sp
    implicitWidth: 260
    spacing: 8

    // real audio outputs (without the apps' streams)
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    Text {
        Layout.leftMargin: 4
        Layout.topMargin: 2
        text: I18n.tr("Sound")
        color: Theme.text
        font.pointSize: 10.5
        font.weight: Font.DemiBold
    }
    Slider {
        Layout.fillWidth: true
        icon: "speaker"
        iconLevel: Sys.volume
        iconOff: Sys.muted
        value: Sys.muted ? 0 : Sys.volume
        onMoved: v => Sys.setVolume(v)
        onIconClicked: Sys.toggleMute()
    }

    Divider {
        Layout.topMargin: 2
        visible: sp.sinks.length > 0
    }
    SectionLabel {
        Layout.leftMargin: 4
        text: I18n.tr("Output")
        visible: sp.sinks.length > 0
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: sp.sinks
            delegate: MenuRow {
                required property var modelData
                Layout.fillWidth: true
                text: Sys.nodeName(modelData)
                checkable: true
                checked: Sys.sink === modelData
                onTriggered: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }
}
