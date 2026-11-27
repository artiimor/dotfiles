pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Menú de Sonido de la barra (como el de macOS): volumen y salida de audio.
// Todo va contra Pipewire, el mismo estado que usan el OSD y la barra normal.
ColumnLayout {
    id: sp
    implicitWidth: 260
    spacing: 8

    // salidas de audio reales (sin los streams de las apps)
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
