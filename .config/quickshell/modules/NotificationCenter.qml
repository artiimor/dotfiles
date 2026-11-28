// Notification panel (Super+A or click on the bell). Same as
// swaync's: do not disturb, music, volume, brightness and the history.
// Closed with Esc or by clicking outside.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: panel

    screen: Theme.focusedScreen
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

    // Click outside the panel = close
    HyprlandFocusGrab {
        windows: [panel]
        active: panel.visible
        onCleared: Notifs.closePanel()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.withAlpha(Theme.bgSolid, 0.97)
        border.width: 1
        border.color: Theme.border

        focus: true
        Keys.onEscapePressed: Notifs.closePanel()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ── Title ────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("Notifications")
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.bold: true
                }

                TextButton {
                    text: "󰎟  " + I18n.tr("Clear")
                    hoverColor: Theme.red
                    textColor: hovered ? Theme.bgSolid : Theme.fg
                    visible: Notifs.count > 0
                    onClicked: Notifs.clearAll()
                }
            }

            // ── No molestar ───────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("Do not disturb")
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

            // ── Music ────────────────────────────────────
            Rectangle {
                id: media
                visible: Player.player !== null
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
                            source: Player.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(112, 112) // twice the painted size (56 px)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !Player.player?.trackArtUrl
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
                            text: Player.player?.trackTitle || Player.player?.identity || ""
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Player.player?.trackArtist ?? ""
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
                        hoverColor: Theme.accent
                        onClicked: Player.player.previous()
                    }
                    BarIcon {
                        implicitHeight: 30
                        padding: 6
                        pixelSize: 18
                        icon: Player.playing ? "󰏤" : "󰐊"
                        color: Theme.accent
                        onClicked: Player.player.togglePlaying()
                    }
                    BarIcon {
                        implicitHeight: 30
                        padding: 6
                        pixelSize: 16
                        icon: "󰒭"
                        hoverColor: Theme.accent
                        onClicked: Player.player.next()
                    }
                }
            }

            // ── Volume and brightness ──────────────────────────
            SliderRow {
                Layout.fillWidth: true
                icon: "󰕾"
                tooltip: I18n.tr("Click: mute")
                value: Audio.volume
                muted: Audio.muted
                onIconClicked: Audio.toggleMute()
                onMoved: v => Audio.setVolume(v)
            }

            // Brightness: only if there is a backlit panel (laptop)
            SliderRow {
                visible: Brightness.available
                Layout.fillWidth: true
                icon: "󰃟"
                iconColor: Theme.yellow
                value: Brightness.percent / 100
                onMoved: v => Brightness.set(v * 100)
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
                    text: "󰂚\n" + I18n.tr("No notifications")
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    lineHeight: 1.6
                }

                // Grouped by app. A group with several is shown collapsed (only
                // the newest); click the header to see them all.
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

                        // Group header (only if there is more than one)
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
                                color: Theme.muted
                                hoverColor: Theme.red
                                tooltip: I18n.tr("Clear group")
                                onClicked: Notifs.clearGroup(group.notifs)
                            }
                        }

                        Repeater {
                            model: !group.many || group.open ? group.notifs : []

                            NotificationCard {
                                width: group.width
                            }
                        }

                        // Collapsed: the newest, with the ones below peeking
                        // out at the bottom like a stack of cards
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
}
