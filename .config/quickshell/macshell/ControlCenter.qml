pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

// macOS-style Control Center.
ColumnLayout {
    id: cc
    signal openWifi()
    signal openAppearance()
    property bool dnd: false
    signal toggleDnd()

    implicitWidth: 320
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Tile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Toggle {
                Layout.fillWidth: true
                icon: "wifi"
                on: Sys.wifiOn
                title: "Wi‑Fi"
                subtitle: !Sys.wifiOn ? I18n.tr("Off")
                    : Sys.wifiNetwork ? Sys.wifiNetwork.name
                    : Sys.wiredUp ? I18n.tr("Ethernet connected") : I18n.tr("Not connected")
                hasChevron: true
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                onChevron: cc.openWifi()
            }
            Toggle {
                Layout.fillWidth: true
                visible: Sys.bt !== null
                icon: "bluetooth"
                on: Sys.btOn
                title: "Bluetooth"
                subtitle: !Sys.btOn ? I18n.tr("Off")
                    : Sys.btConnected.length ? Sys.btConnected.map(d => d.name).join(", ") : I18n.tr("On")
                onToggled: if (Sys.bt) Sys.bt.enabled = !Sys.bt.enabled
            }
        }

        Tile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            // takes the full height: Toggle centers its content vertically
            Toggle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "moon"
                on: cc.dnd
                title: I18n.tr("Do Not Disturb")
                subtitle: cc.dnd ? I18n.tr("On") : ""
                onToggled: cc.toggleDnd()
            }
        }
    }

    // Night Shift (night light, hyprsunset) and Keep Awake (caffeine from the root config)
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Tile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Toggle {
                Layout.fillWidth: true
                icon: "sunset"
                on: Sys.nightOn
                title: I18n.tr("Night Shift")
                subtitle: Sys.nightState === "unavailable" ? I18n.tr("Unavailable") : Sys.nightOn ? I18n.tr("On") : I18n.tr("Off")
                onToggled: Sys.toggleNight()
            }
        }
        Tile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Toggle {
                Layout.fillWidth: true
                icon: "cup"
                on: Sys.caffeine
                title: I18n.tr("Keep Awake")
                subtitle: Sys.caffeine ? I18n.tr("On") : I18n.tr("Off")
                onToggled: Sys.toggleCaffeine()
            }
        }
    }

    // Increase contrast (accessibility): opaque backgrounds and marked borders
    Tile {
        Layout.fillWidth: true
        Toggle {
            Layout.fillWidth: true
            icon: "contrast"
            on: Theme.contrast
            title: I18n.tr("Increase Contrast")
            subtitle: Theme.contrast ? I18n.tr("On") : I18n.tr("Off")
            onToggled: Sys.toggleContrast()
        }
    }

    // Brightness: only if there is a backlit panel (laptop)
    Tile {
        visible: Sys.hasBacklight
        Layout.fillWidth: true
        spacing: 6
        Text { text: I18n.tr("Display"); color: Theme.text; font.pointSize: 9.5; font.weight: Font.DemiBold }
        Slider {
            Layout.fillWidth: true
            icon: "sun"
            value: Sys.brightness
            onMoved: v => Sys.setBrightness(v)
        }
    }

    Tile {
        Layout.fillWidth: true
        spacing: 6
        Text { text: I18n.tr("Sound"); color: Theme.text; font.pointSize: 9.5; font.weight: Font.DemiBold }
        Slider {
            Layout.fillWidth: true
            icon: "speaker"
            iconLevel: Sys.volume
            iconOff: Sys.muted
            value: Sys.muted ? 0 : Sys.volume
            onMoved: v => Sys.setVolume(v)
            onIconClicked: Sys.toggleMute()
        }
    }

    Tile {
        Layout.fillWidth: true
        visible: Sys.player !== null
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 44; implicitHeight: 44
                radius: 8
                color: Theme.tint(0.1)
                clip: true
                Image {
                    anchors.fill: parent
                    source: Sys.player ? Sys.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(88, 88)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: Sys.player ? (Sys.player.trackTitle || Sys.player.identity) : ""
                    textFormat: Text.PlainText
                    color: Theme.text; font.pointSize: 9.5; font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: Sys.player ? Sys.player.trackArtist : ""
                    textFormat: Text.PlainText
                    color: Theme.dim; font.pointSize: 8.5
                    elide: Text.ElideRight
                }
            }
            Repeater {
                model: [
                    { n: "prev", f: () => Sys.player.previous() },
                    { n: "playpause", f: () => Sys.player.togglePlaying() },
                    { n: "next", f: () => Sys.player.next() }
                ]
                delegate: Item {
                    id: ctl
                    required property var modelData
                    implicitWidth: 22; implicitHeight: 22
                    Glyph {
                        anchors.centerIn: parent
                        width: ctl.modelData.n === "playpause" ? 16 : 13; height: width
                        name: ctl.modelData.n === "playpause" ? (Sys.player && Sys.player.isPlaying ? "pause" : "play") : ctl.modelData.n
                    }
                    MouseArea { anchors.fill: parent; onClicked: ctl.modelData.f() }
                }
            }
        }
    }

    Divider {}

    MenuRow {
        Layout.fillWidth: true
        text: I18n.tr("Appearance Settings…")
        onTriggered: cc.openAppearance()
    }
}
