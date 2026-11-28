pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// Bar Wi‑Fi popup: switch, network list and access to the Network window.
ColumnLayout {
    id: wp
    signal done()
    signal openSettings()
    implicitWidth: 300
    spacing: 6

    property string askingFor: ""   // network waiting for a password

    Component.onCompleted: Sys.scanUsers++
    Component.onDestruction: Sys.scanUsers--

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 4
        Text {
            Layout.fillWidth: true
            text: "Wi‑Fi"
            color: Theme.text
            font.pointSize: 10.5
            font.weight: Font.DemiBold
        }
        Switch {
            implicitWidth: 32; implicitHeight: 18
            on: Sys.wifiOn
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    SectionLabel {
        visible: Sys.wifiOn
        Layout.leftMargin: 4
        text: I18n.tr("Networks")
    }

    Column {
        visible: Sys.wifiOn
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            // ScriptModel and not an array: every signal change brings a new list
            // and this way the rows are reused (without losing a half-typed password)
            model: ScriptModel {
                values: Sys.wifiDevice
                    ? Sys.wifiDevice.networks.values.slice()
                        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
                        .slice(0, 10)
                    : []
            }
            delegate: Column {
                id: rowItem
                required property var modelData
                readonly property bool secured: modelData.security !== WifiSecurityType.Open
                width: parent.width

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 7
                    color: rowMouse.containsMouse ? Theme.tint(0.10) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6; anchors.rightMargin: 8
                        spacing: 8
                        Rectangle {
                            implicitWidth: 24; implicitHeight: 24; radius: 12
                            color: rowItem.modelData.connected ? Theme.accent : Theme.tint(0.12)
                            Glyph {
                                anchors.centerIn: parent
                                width: 13; height: 13
                                name: "wifi"
                                level: Sys.wifiBars(rowItem.modelData.signalStrength)
                                color: "white"
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: rowItem.modelData.name
                            color: Theme.text
                            font.pointSize: 9.5
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: rowItem.modelData.stateChanging
                            text: I18n.tr("Connecting…")
                            color: Theme.dim
                            font.pointSize: 8.5
                        }
                        Glyph {
                            visible: rowItem.secured
                            name: "lock"
                            color: Theme.dim
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const n = rowItem.modelData;
                            if (n.connected) n.disconnect();
                            else if (n.known || !rowItem.secured) n.connect();
                            else wp.askingFor = (wp.askingFor === n.name ? "" : n.name);
                        }
                    }
                }

                // password for a new protected network
                PasswordField {
                    visible: wp.askingFor === rowItem.modelData.name
                    width: parent.width
                    implicitHeight: 30
                    placeholder: I18n.tr("Password — press Enter")
                    onSubmitted: psk => {
                        rowItem.modelData.connectWithPsk(psk);
                        wp.askingFor = "";
                    }
                }
            }
        }
    }

    Divider {}

    MenuRow {
        Layout.fillWidth: true
        text: I18n.tr("Network Settings…")
        onTriggered: { wp.openSettings(); wp.done(); }
    }
}
