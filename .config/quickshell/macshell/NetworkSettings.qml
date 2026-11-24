pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// "Network" window in the style of macOS System Settings. Opened from
// "Network Settings…" in the Wi‑Fi panel on Hyprland (`ipc call network open`).
// Live state comes from Quickshell.Networking; details, saved connections and
// VPNs from nmcli.
FloatingWindow {
    id: win
    title: "Network"
    visible: false
    color: Theme.window
    implicitWidth: 560
    implicitHeight: 660
    minimumSize: Qt.size(460, 420)

    // If it's already open (maybe on another workspace, or closed from the
    // titlebar without us noticing) recreate it so it shows up where you are
    function show() {
        if (visible) { visible = false; Qt.callLater(() => { win.visible = true; }); }
        else visible = true;
        refresh();
    }

    // ── data from nmcli ──
    property var saved: []        // [{ name, uuid, type }]
    property var activeUuids: []
    property var wifiInfo: ({})   // IP4.ADDRESS[1], IP4.GATEWAY, IP4.DNS[1], GENERAL.HWADDR...
    property var wiredInfo: ({})
    property string expanded: ""  // uuid of the saved row showing its buttons
    property bool showDetails: false
    property string askingFor: ""

    readonly property var wifiDev: Sys.wifiDevice
    readonly property var wiredDev: Sys.wiredDevice
    readonly property var current: Sys.wifiNetwork
    readonly property var savedWifi: saved.filter(c => c.type === "802-11-wireless" && (!current || c.name !== current.name))
    readonly property var vpns: saved.filter(c => c.type === "vpn" || c.type === "wireguard")
    readonly property var others: wifiDev
        ? wifiDev.networks.values.filter(n => !n.connected && !n.known && n.name)
            .sort((a, b) => b.signalStrength - a.signalStrength).slice(0, 12)
        : []

    function nm(args) { Quickshell.execDetached(["nmcli"].concat(args)); refreshSoon.restart(); }

    function refresh() {
        savedProc.running = true;
        activeProc.running = true;
        if (wifiDev) { wifiInfoProc.dev = wifiDev.name; wifiInfoProc.running = true; }
        if (wiredDev) { wiredInfoProc.dev = wiredDev.name; wiredInfoProc.running = true; }
    }

    // nmcli -t escapes ":" inside values as "\:"
    function parseFields(text) {
        const out = {};
        text.split("\n").forEach(l => {
            const i = l.indexOf(":");
            if (i > 0) out[l.slice(0, i)] = l.slice(i + 1).replace(/\\:/g, ":");
        });
        return out;
    }
    function splitTerse(l) { return l.split(/(?<!\\):/).map(f => f.replace(/\\:/g, ":")); }

    Timer { id: refreshSoon; interval: 1200; onTriggered: win.refresh() }
    Timer { interval: 4000; repeat: true; running: win.visible; onTriggered: win.refresh() }

    onVisibleChanged: Sys.scanUsers += visible ? 1 : -1

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: win.saved = text.split("\n").filter(l => l).map(l => {
                const f = win.splitTerse(l);
                return { name: f[0], uuid: f[1], type: f[2] };
            })
        }
    }
    Process {
        id: activeProc
        command: ["nmcli", "-t", "-f", "UUID", "connection", "show", "--active"]
        stdout: StdioCollector { onStreamFinished: win.activeUuids = text.split("\n").filter(l => l) }
    }
    Process {
        id: wifiInfoProc
        property string dev: ""
        command: ["nmcli", "-t", "-f", "GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "device", "show", dev]
        stdout: StdioCollector { onStreamFinished: win.wifiInfo = win.parseFields(text) }
    }
    Process {
        id: wiredInfoProc
        property string dev: ""
        command: ["nmcli", "-t", "-f", "GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "device", "show", dev]
        stdout: StdioCollector { onStreamFinished: win.wiredInfo = win.parseFields(text) }
    }

    // ── building blocks ──
    component SectionTitle: Text {
        Layout.topMargin: 14
        Layout.leftMargin: 4
        color: Theme.dim
        font.pointSize: 9
        font.weight: Font.DemiBold
    }

    // rounded grouped box like System Settings
    component Group: Rectangle {
        default property alias rows: groupCol.data
        Layout.fillWidth: true
        implicitHeight: groupCol.implicitHeight
        radius: 10
        color: Theme.tint(0.05)
        border.color: Theme.tint(0.08)
        ColumnLayout {
            id: groupCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 0
        }
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        implicitHeight: 1
        color: Theme.tint(0.07)
    }

    component Switch: Rectangle {
        property bool on: false
        signal toggled()
        implicitWidth: 38; implicitHeight: 22; radius: 11
        color: on ? Theme.accent : Theme.tint(0.2)
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            width: 18; height: 18; radius: 9; y: 2
            x: parent.on ? parent.width - width - 2 : 2
            color: "white"
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; onClicked: parent.toggled() }
    }

    component PillButton: Rectangle {
        property string text: ""
        property bool danger: false
        signal clicked()
        implicitWidth: pbText.implicitWidth + 22
        implicitHeight: 24
        radius: 6
        color: pbMouse.containsMouse ? Theme.tint(0.20) : Theme.tint(0.12)
        Text {
            id: pbText
            anchors.centerIn: parent
            text: parent.text
            color: parent.danger ? "#ff6961" : Theme.text
            font.pointSize: 9.5
        }
        MouseArea { id: pbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }

    component IconBadge: Rectangle {
        property string glyph: ""
        property real level: 3
        property color tint: Theme.accent
        implicitWidth: 28; implicitHeight: 28; radius: 7
        color: tint
        Glyph { anchors.centerIn: parent; width: 16; height: 16; name: parent.glyph; level: parent.level; color: "white" }
    }

    component InfoRow: RowLayout {
        property string label: ""
        property string value: ""
        visible: value !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 14
        Layout.rightMargin: 14
        implicitHeight: 28
        Text { text: parent.label; color: Theme.text; font.pointSize: 9.5; Layout.fillWidth: true }
        Text { text: parent.value; color: Theme.dim; font.pointSize: 9.5 }
    }

    // ── content ──
    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            x: 20; y: 16
            width: parent.width - 40
            spacing: 6

            Text {
                text: "Network"
                color: Theme.text
                font.pointSize: 15
                font.weight: Font.Bold
                Layout.bottomMargin: 4
            }

            // ── Wi‑Fi ──
            Group {
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    spacing: 10
                    IconBadge { glyph: "wifi"; tint: Sys.wifiOn ? Theme.accent : Theme.tint(0.18) }
                    ColumnLayout {
                        spacing: 1
                        Text { text: "Wi‑Fi"; color: Theme.text; font.pointSize: 10.5; font.weight: Font.DemiBold }
                        Text {
                            text: !Sys.wifiOn ? "Off" : win.current ? "Connected" : "Not connected"
                            color: Theme.dim; font.pointSize: 9
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Switch { on: Sys.wifiOn; onToggled: Networking.wifiEnabled = !Networking.wifiEnabled }
                }

                Divider { visible: Sys.wifiOn && win.current !== null }

                // current network
                RowLayout {
                    visible: Sys.wifiOn && win.current !== null
                    Layout.fillWidth: true
                    Layout.margins: 12
                    spacing: 10
                    Glyph { name: "check"; color: Theme.accent }
                    Text {
                        Layout.fillWidth: true
                        text: win.current?.name ?? ""
                        color: Theme.text; font.pointSize: 10
                        elide: Text.ElideRight
                    }
                    Glyph {
                        visible: win.current && win.current.security !== WifiSecurityType.Open
                        name: "lock"; color: Theme.dim
                    }
                    Glyph { name: "wifi"; level: Sys.wifiLevel; color: Theme.text }
                    PillButton { text: win.showDetails ? "Hide Details" : "Details…"; onClicked: win.showDetails = !win.showDetails }
                }

                ColumnLayout {
                    visible: win.showDetails && Sys.wifiOn && win.current !== null
                    Layout.fillWidth: true
                    Layout.bottomMargin: 10
                    spacing: 0
                    Divider {}
                    InfoRow { label: "IP Address"; value: (win.wifiInfo["IP4.ADDRESS[1]"] ?? "").split("/")[0] }
                    InfoRow { label: "Subnet"; value: (win.wifiInfo["IP4.ADDRESS[1]"] ?? "").includes("/") ? "/" + win.wifiInfo["IP4.ADDRESS[1]"].split("/")[1] : "" }
                    InfoRow { label: "Router"; value: win.wifiInfo["IP4.GATEWAY"] ?? "" }
                    InfoRow { label: "DNS"; value: [1, 2, 3].map(i => win.wifiInfo["IP4.DNS[" + i + "]"]).filter(x => x).join(", ") }
                    InfoRow { label: "IPv6 Address"; value: (win.wifiInfo["IP6.ADDRESS[1]"] ?? "").split("/")[0] }
                    InfoRow { label: "Wi‑Fi Address"; value: win.wifiInfo["GENERAL.HWADDR"] ?? "" }
                    InfoRow { label: "Signal"; value: win.current ? Math.round(win.current.signalStrength * 100) + " %" : "" }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 6
                        spacing: 8
                        Item { Layout.fillWidth: true }
                        PillButton { text: "Disconnect"; onClicked: { win.current.disconnect(); win.showDetails = false; } }
                        PillButton {
                            text: "Forget This Network…"
                            danger: true
                            onClicked: {
                                const c = win.saved.find(s => s.type === "802-11-wireless" && s.name === win.current.name);
                                if (c) win.nm(["connection", "delete", "uuid", c.uuid]);
                                win.showDetails = false;
                            }
                        }
                    }
                }
            }

            // ── Known networks ──
            SectionTitle { visible: Sys.wifiOn && win.savedWifi.length > 0; text: "Known Networks" }
            Group {
                visible: Sys.wifiOn && win.savedWifi.length > 0
                Repeater {
                    model: win.savedWifi
                    delegate: ColumnLayout {
                        id: known
                        required property var modelData
                        required property int index
                        readonly property var live: win.wifiDev ? win.wifiDev.networks.values.find(n => n.name === modelData.name) ?? null : null
                        Layout.fillWidth: true
                        spacing: 0
                        Divider { visible: known.index > 0 }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            color: knownHover.hovered ? Theme.tint(0.04) : "transparent"
                            radius: 10
                            HoverHandler { id: knownHover }
                            MouseArea {
                                id: knownMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.nm(["connection", "up", "uuid", known.modelData.uuid])
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 12
                                spacing: 10
                                Text {
                                    Layout.fillWidth: true
                                    text: known.modelData.name
                                    color: Theme.text; font.pointSize: 10
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: !known.live
                                    text: "Not in range"
                                    color: Theme.dim; font.pointSize: 9
                                }
                                Glyph {
                                    visible: known.live !== null
                                    name: "wifi"
                                    level: known.live ? Math.max(1, Math.ceil(known.live.signalStrength * 3)) : 0
                                    color: Theme.text
                                }
                                PillButton {
                                    visible: knownHover.hovered
                                    text: "Forget"
                                    danger: true
                                    onClicked: win.nm(["connection", "delete", "uuid", known.modelData.uuid])
                                }
                            }
                        }
                    }
                }
            }

            // ── Other networks ──
            SectionTitle { visible: Sys.wifiOn; text: "Other Networks" }
            Group {
                visible: Sys.wifiOn
                Text {
                    visible: win.others.length === 0
                    Layout.margins: 14
                    text: "Searching…"
                    color: Theme.dim; font.pointSize: 9.5
                }
                Repeater {
                    model: win.others
                    delegate: ColumnLayout {
                        id: other
                        required property var modelData
                        required property int index
                        readonly property bool secured: modelData.security !== WifiSecurityType.Open
                        Layout.fillWidth: true
                        spacing: 0
                        Divider { visible: other.index > 0 }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 10
                            color: otherMouse.containsMouse ? Theme.tint(0.04) : "transparent"
                            MouseArea {
                                id: otherMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (!other.secured) other.modelData.connect();
                                    else win.askingFor = (win.askingFor === other.modelData.name ? "" : other.modelData.name);
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14; anchors.rightMargin: 14
                                spacing: 10
                                Text {
                                    Layout.fillWidth: true
                                    text: other.modelData.name
                                    color: Theme.text; font.pointSize: 10
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: other.modelData.stateChanging
                                    text: "Connecting…"
                                    color: Theme.dim; font.pointSize: 9
                                }
                                Glyph { visible: other.secured; name: "lock"; color: Theme.dim }
                                Glyph {
                                    name: "wifi"
                                    level: Math.max(1, Math.ceil(other.modelData.signalStrength * 3))
                                    color: Theme.text
                                }
                            }
                        }
                        // password for a new secured network
                        RowLayout {
                            visible: win.askingFor === other.modelData.name
                            Layout.fillWidth: true
                            Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 10
                            spacing: 8
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: 6
                                color: Theme.tint(0.08)
                                border.color: pass.activeFocus ? Theme.accent : Theme.tint(0.12)
                                TextInput {
                                    id: pass
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    color: Theme.text
                                    font.pointSize: 9.5
                                    onVisibleChanged: if (visible) forceActiveFocus()
                                    onAccepted: join.clicked()
                                    Text {
                                        visible: !pass.text.length
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Password"
                                        color: Theme.dim; font.pointSize: 9.5
                                    }
                                }
                            }
                            PillButton {
                                id: join
                                text: "Join"
                                onClicked: {
                                    other.modelData.connectWithPsk(pass.text);
                                    pass.text = "";
                                    win.askingFor = "";
                                }
                            }
                        }
                    }
                }
            }

            // ── Ethernet ──
            SectionTitle { visible: win.wiredDev !== null; text: "Ethernet" }
            Group {
                visible: win.wiredDev !== null
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    spacing: 10
                    IconBadge { glyph: "ethernet"; tint: Sys.wiredUp ? "#30d158" : Theme.tint(0.18) }
                    ColumnLayout {
                        spacing: 1
                        Text { text: "Ethernet"; color: Theme.text; font.pointSize: 10.5; font.weight: Font.DemiBold }
                        Text {
                            text: Sys.wiredUp ? "Connected" : "Cable unplugged"
                            color: Theme.dim; font.pointSize: 9
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
                ColumnLayout {
                    visible: Sys.wiredUp
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    spacing: 0
                    Divider {}
                    InfoRow { label: "IP Address"; value: (win.wiredInfo["IP4.ADDRESS[1]"] ?? "").split("/")[0] }
                    InfoRow { label: "Router"; value: win.wiredInfo["IP4.GATEWAY"] ?? "" }
                    InfoRow { label: "Hardware Address"; value: win.wiredInfo["GENERAL.HWADDR"] ?? "" }
                }
            }

            // ── VPN ──
            SectionTitle { visible: win.vpns.length > 0; text: "VPN" }
            Group {
                visible: win.vpns.length > 0
                Repeater {
                    model: win.vpns
                    delegate: ColumnLayout {
                        id: vpn
                        required property var modelData
                        required property int index
                        readonly property bool active: win.activeUuids.includes(modelData.uuid)
                        Layout.fillWidth: true
                        spacing: 0
                        Divider { visible: vpn.index > 0 }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: 12
                            spacing: 10
                            IconBadge { glyph: "lock"; tint: vpn.active ? Theme.accent : Theme.tint(0.18) }
                            ColumnLayout {
                                spacing: 1
                                Text { text: vpn.modelData.name; color: Theme.text; font.pointSize: 10 }
                                Text { text: vpn.active ? "Connected" : "Not connected"; color: Theme.dim; font.pointSize: 9 }
                            }
                            Item { Layout.fillWidth: true }
                            Switch {
                                on: vpn.active
                                onToggled: win.nm(["connection", vpn.active ? "down" : "up", "uuid", vpn.modelData.uuid])
                            }
                        }
                    }
                }
            }
        }
    }
}
