// Mezclador de volumen (clic en el icono de audio de la barra): la salida
// actual y cada app que está sonando por ella. Se cierra haciendo clic fuera.
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

    // Las apps que mandan audio a la salida actual
    // (solo con el mezclador abierto; el icono de la barra sigue la salida por su cuenta)
    PwNodeLinkTracker {
        id: links
        node: root.visible ? root.sink : null
    }
    readonly property var apps: links.linkGroups.map(g => g.source).filter(n => n?.audio)
    // Sin esto Pipewire no rellena node.audio (la salida ya la sigue Audio)
    PwObjectTracker { objects: root.visible ? root.apps : [] }

    Column {
        id: column
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 10

        Channel {
            node: root.sink
            label: root.sink?.description ?? "Sin salida de audio"
        }

        Repeater {
            model: root.apps

            Channel {
                required property PwNode modelData
                node: modelData
                label: modelData.properties["application.name"] || modelData.description || modelData.name
            }
        }

        // Lo que no está aquí (dispositivos, micrófono...)
        BarIcon {
            anchors.right: parent.right
            implicitHeight: 24
            padding: 4
            icon: "Más ajustes  󰒓"
            pixelSize: Theme.fontSize
            color: Theme.muted
            hoverColor: Theme.accent
            onClicked: {
                root.close();
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
    }

    // Nombre y volumen de un nodo. Clic en el icono: silenciar
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
