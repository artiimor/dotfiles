pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

ColumnLayout {
    id: wp
    signal done()
    signal openSettings()
    implicitWidth: 300
    spacing: 6

    property string askingFor: ""   // network name waiting for a password

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
        // macOS switch
        Rectangle {
            implicitWidth: 32; implicitHeight: 18; radius: 9
            color: Sys.wifiOn ? Theme.accent : Theme.tint(0.2)
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                width: 14; height: 14; radius: 7
                y: 2
                x: Sys.wifiOn ? parent.width - width - 2 : 2
                color: "white"
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; onClicked: Networking.wifiEnabled = !Networking.wifiEnabled }
        }
    }

    Text {
        visible: Sys.wifiOn
        Layout.leftMargin: 4
        text: "Networks"
        color: Theme.dim
        font.pointSize: 8.5
        font.weight: Font.DemiBold
    }

    Column {
        visible: Sys.wifiOn
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: Sys.wifiDevice
                ? Sys.wifiDevice.networks.values.slice()
                    .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
                    .slice(0, 10)
                : []
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
                                level: Math.max(1, Math.ceil(rowItem.modelData.signalStrength * 3))
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
                            text: "Connecting…"
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

                // password prompt for new secured networks
                Rectangle {
                    visible: wp.askingFor === rowItem.modelData.name
                    width: parent.width
                    height: visible ? 30 : 0
                    radius: 7
                    color: Theme.tint(0.10)
                    border.color: pass.activeFocus ? Theme.accent : "transparent"
                    TextInput {
                        id: pass
                        anchors.fill: parent
                        anchors.margins: 8
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.text
                        font.pointSize: 9.5
                        focus: parent.visible
                        onVisibleChanged: if (visible) forceActiveFocus()
                        onAccepted: {
                            rowItem.modelData.connectWithPsk(text);
                            text = "";
                            wp.askingFor = "";
                        }
                        Text {
                            visible: !pass.text.length
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password — press Enter"
                            color: Theme.dim
                            font.pointSize: 9.5
                        }
                    }
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.tint(0.1) }

    MenuRow {
        Layout.fillWidth: true
        text: "Network Settings…"
        onTriggered: { wp.openSettings(); wp.done(); }
    }
}
