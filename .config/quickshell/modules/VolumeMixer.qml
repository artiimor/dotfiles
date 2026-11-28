// Volume mixer (click the audio icon in the bar): the current
// output and each app playing through it. Closed by clicking outside.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

BarPopup {
    id: root

    readonly property PwNode sink: Audio.sink

    implicitWidth: 320
    implicitHeight: column.implicitHeight + 24

    // The apps sending audio to the current output
    // (only with the mixer open; the bar icon tracks the output on its own)
    PwNodeLinkTracker {
        id: links
        node: root.visible ? root.sink : null
    }
    readonly property var apps: links.linkGroups.map(g => g.source).filter(n => n?.audio)
    // Without this Pipewire doesn't fill node.audio (the output is already tracked by Audio)
    PwObjectTracker { objects: root.visible ? root.apps : [] }

    Column {
        id: column
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 10

        Channel {
            node: root.sink
            label: root.sink?.description ?? I18n.tr("No audio output")
        }

        Repeater {
            model: root.apps

            Channel {
                required property PwNode modelData
                node: modelData
                label: modelData.properties["application.name"] || modelData.description || modelData.name
            }
        }

        // What isn't here (devices, microphone...)
        BarIcon {
            anchors.right: parent.right
            implicitHeight: 24
            padding: 4
            icon: I18n.tr("More settings") + "  󰒓"
            pixelSize: Theme.fontSize
            color: Theme.muted
            hoverColor: Theme.accent
            onClicked: {
                root.close();
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
    }

    // Name and volume of a node. Click on the icon: mute
    component Channel: Column {
        id: channel
        required property PwNode node
        property string label
        readonly property bool muted: node?.audio?.muted ?? false

        width: parent?.width ?? 0
        spacing: 2

        Text {
            width: parent.width
            text: channel.label
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
        }
        SliderRow {
            visible: channel.node !== null
            width: parent.width
            icon: "󰕾"
            value: channel.node?.audio?.volume ?? 0
            muted: channel.muted
            onIconClicked: channel.node.audio.muted = !channel.muted
            onMoved: v => channel.node.audio.volume = v
        }
    }
}
