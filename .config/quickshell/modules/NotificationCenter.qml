// Panel de notificaciones (Super+A o clic en la campana). Igual que el de
// swaync: no molestar, música, volumen, brillo y el historial.
// Se cierra con Esc o haciendo clic fuera.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

PanelWindow {
    id: panel

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Notifs.centerOpen

    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: Theme.gap
        right: Theme.gap
        bottom: Theme.gap
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-notification-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    implicitWidth: 420
    color: "transparent"

    // Clic fuera del panel = cerrar
    HyprlandFocusGrab {
        windows: [panel]
        active: panel.visible
        onCleared: Notifs.closePanel()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Qt.rgba(Theme.bgSolid.r, Theme.bgSolid.g, Theme.bgSolid.b, 0.97)
        border.width: 1
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: Notifs.closePanel()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ── Título ────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Notificaciones"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.bold: true
                }

                PanelButton {
                    text: "󰎟  Limpiar"
                    visible: Notifs.count > 0
                    onClicked: Notifs.clearAll()
                }
            }

            // ── No molestar ───────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "No molestar"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                // Interruptor
                Rectangle {
                    implicitWidth: 44
                    implicitHeight: 24
                    radius: 12
                    color: Notifs.dnd ? Theme.accentDim : Theme.surface

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        y: 3
                        x: Notifs.dnd ? parent.width - width - 3 : 3
                        color: Notifs.dnd ? Theme.accent : Theme.muted
                        Behavior on x {
                            NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.toggleDnd()
                    }
                }
            }

            // ── Música ────────────────────────────────────
            Rectangle {
                id: media
                readonly property MprisPlayer player: {
                    const ps = Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"));
                    return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
                }
                visible: player !== null
                Layout.fillWidth: true
                implicitHeight: 76
                radius: Theme.radius
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        implicitWidth: 56
                        implicitHeight: 56
                        radius: 8
                        color: Theme.bgSolid
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: media.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !media.player?.trackArtUrl
                            text: "󰎈"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 22
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: media.player?.trackTitle || media.player?.identity || ""
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: media.player?.trackArtist ?? ""
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }

                    BarIcon {
                        implicitHeight: 30
                        padding: 6
                        pixelSize: 16
                        icon: "󰒮"
                        color: hovered ? Theme.accent : Theme.fg
                        onClicked: media.player.previous()
                    }
                    BarIcon {
                        implicitHeight: 30
                        padding: 6
                        pixelSize: 18
                        icon: media.player?.isPlaying ? "󰏤" : "󰐊"
                        color: Theme.accent
                        onClicked: media.player.togglePlaying()
                    }
                    BarIcon {
                        implicitHeight: 30
                        padding: 6
                        pixelSize: 16
                        icon: "󰒭"
                        color: hovered ? Theme.accent : Theme.fg
                        onClicked: media.player.next()
                    }
                }
            }

            // ── Volumen y brillo ──────────────────────────
            PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                BarIcon {
                    readonly property var audio: Pipewire.defaultAudioSink?.audio
                    implicitHeight: 24
                    padding: 4
                    pixelSize: 15
                    icon: audio?.muted ? "󰝟" : "󰕾"
                    color: audio?.muted ? Theme.muted : Theme.accent
                    tooltip: "Clic: silenciar"
                    onClicked: audio.muted = !audio.muted
                }
                Slider {
                    Layout.fillWidth: true
                    value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                    enabled: !(Pipewire.defaultAudioSink?.audio?.muted ?? false)
                    onMoved: v => Pipewire.defaultAudioSink.audio.volume = v
                }
                Text {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                BarIcon {
                    implicitHeight: 24
                    padding: 4
                    pixelSize: 15
                    icon: "󰃟"
                    color: Theme.yellow
                }
                Slider {
                    Layout.fillWidth: true
                    value: Brightness.percent / 100
                    onMoved: v => Brightness.set(Math.max(1, Math.round(v * 100)) + "%")
                }
                Text {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: Brightness.percent + "%"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            // ── Historial ─────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    visible: Notifs.count === 0
                    text: "󰂚\nSin notificaciones"
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    lineHeight: 1.6
                }

                // Agrupadas por app. Un grupo con varias se ve plegado (solo
                // la más nueva); clic en la cabecera para verlas todas.
                ListView {
                    anchors.fill: parent
                    clip: true
                    spacing: Theme.gap * 1.5
                    model: Notifs.groups
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Column {
                        id: group
                        required property var modelData
                        readonly property var notifs: modelData.notifs
                        readonly property bool many: notifs.length > 1
                        readonly property bool open: Notifs.expanded[modelData.app] ?? false

                        width: ListView.view.width
                        spacing: 6

                        // Cabecera del grupo (solo si hay más de una)
                        Item {
                            visible: group.many
                            width: parent.width
                            height: 24

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.toggleGroup(group.modelData.app)
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: `${group.open ? "󰅀" : "󰅂"}  ${group.modelData.app}  ·  ${group.notifs.length}`
                                color: Theme.accent
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                            }

                            BarIcon {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitHeight: 24
                                padding: 4
                                icon: "󰎟"
                                color: hovered ? Theme.red : Theme.muted
                                tooltip: "Borrar el grupo"
                                onClicked: Notifs.clearGroup(group.notifs)
                            }
                        }

                        Repeater {
                            model: !group.many || group.open ? group.notifs : []

                            NotificationCard {
                                width: group.width
                            }
                        }

                        // Plegado: la más nueva, con las de debajo asomando
                        // por abajo como un montón de tarjetas
                        Item {
                            visible: group.many && !group.open
                            width: group.width
                            height: visible ? topCard.height + 4 * stackRepeater.count : 0

                            Repeater {
                                id: stackRepeater
                                model: Math.min(2, group.notifs.length - 1)

                                Rectangle {
                                    required property int index
                                    readonly property int level: index + 1
                                    z: -level
                                    x: 10 * level
                                    y: topCard.height - 8 + 4 * level
                                    width: parent.width - 20 * level
                                    height: 8
                                    radius: 5
                                    color: Theme.surface
                                    border.width: 1
                                    border.color: Theme.border
                                    opacity: 1 - 0.35 * index
                                }
                            }

                            NotificationCard {
                                id: topCard
                                width: parent.width
                                modelData: group.notifs[0]
                            }
                        }
                    }
                }
            }
        }
    }

    // Botón con texto del panel
    component PanelButton: Rectangle {
        property alias text: label.text
        signal clicked

        implicitWidth: label.implicitWidth + 20
        implicitHeight: 28
        radius: 7
        color: mouse.containsMouse ? Theme.red : Theme.surface

        Behavior on color {
            ColorAnimation { duration: Theme.anim }
        }

        Text {
            id: label
            anchors.centerIn: parent
            color: mouse.containsMouse ? Theme.bgSolid : Theme.fg
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
