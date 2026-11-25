pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

// macOS Control Center.
ColumnLayout {
    id: cc
    signal openWifi()
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
            implicitHeight: conn.implicitHeight + 20
            ColumnLayout {
                id: conn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 8
                Toggle {
                    Layout.fillWidth: true
                    icon: "wifi"
                    iconLevel: 3
                    on: Sys.wifiOn
                    title: "Wi‑Fi"
                    subtitle: !Sys.wifiOn ? "Off"
                        : Sys.wifiNetwork ? Sys.wifiNetwork.name
                        : Sys.wiredUp ? "Ethernet connected" : "Not connected"
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
                    subtitle: !Sys.btOn ? "Off"
                        : Sys.btConnected.length ? Sys.btConnected.map(d => d.name).join(", ") : "On"
                    onToggled: if (Sys.bt) Sys.bt.enabled = !Sys.bt.enabled
                }
            }
        }

        Tile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Toggle {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                icon: "moon"
                on: cc.dnd
                title: "Do Not Disturb"
                subtitle: cc.dnd ? "On" : ""
                onToggled: cc.toggleDnd()
            }
        }
    }

    // Brillo: solo si hay panel retroiluminado (portátil)
    Tile {
        visible: Sys.hasBacklight
        Layout.fillWidth: true
        implicitHeight: dispCol.implicitHeight + 20
        ColumnLayout {
            id: dispCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 6
            Text { text: "Display"; color: Theme.text; font.pointSize: 9.5; font.weight: Font.DemiBold }
            Slider {
                Layout.fillWidth: true
                icon: "sun"
                value: Sys.brightness
                onMoved: v => Sys.setBrightness(v)
            }
        }
    }

    Tile {
        Layout.fillWidth: true
        implicitHeight: sndCol.implicitHeight + 20
        ColumnLayout {
            id: sndCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 6
            Text { text: "Sound"; color: Theme.text; font.pointSize: 9.5; font.weight: Font.DemiBold }
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
    }

    Tile {
        Layout.fillWidth: true
        visible: Sys.player !== null
        implicitHeight: 64
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
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
                    color: Theme.text; font.pointSize: 9.5; font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: Sys.player ? Sys.player.trackArtist : ""
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
}
