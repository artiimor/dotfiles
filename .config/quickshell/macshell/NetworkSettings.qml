pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Ventana "Network" al estilo de Ajustes del Sistema de macOS. Se abre desde
// "Network Settings…" en el panel Wi‑Fi en Hyprland (`ipc call network open`).
// El estado en vivo sale de Quickshell.Networking; los detalles, las conexiones
// guardadas y las VPN, de nmcli.
FloatingWindow {
    id: win
    title: "Network" // sin traducir: lo busca una regla de hypr/config/windowrules.lua
    visible: false
    color: Theme.window
    implicitWidth: 560
    implicitHeight: 660
    minimumSize: Qt.size(460, 420)

    // Si ya está abierta (quizá en otro workspace) se recrea para que aparezca donde estás
    function show() {
        if (visible) { visible = false; Qt.callLater(() => { win.visible = true; }); }
        else visible = true;
        refresh();
    }
    // Cerrada desde Hyprland (Super+Q, barra de título): visible no cambia solo, y
    // sin esto seguirían el escaneo y el Timer de nmcli
    onClosed: visible = false

    // ── datos de nmcli ──
    property var saved: []        // [{ name, uuid, type }]
    property var ssids: ({})      // uuid → SSID de las Wi‑Fi guardadas (el NAME puede ser otro)
    property var activeUuids: []
    property var wifiInfo: ({})   // IP4.ADDRESS[1], IP4.GATEWAY, IP4.DNS[1], GENERAL.HWADDR...
    property var wiredInfo: ({})
    property bool showDetails: false
    property string askingFor: ""

    readonly property var wifiDev: Sys.wifiDevice
    readonly property var wiredDev: Sys.wiredDevice
    readonly property var current: Sys.wifiNetwork
    readonly property var savedWifi: saved.filter(c => c.type === "802-11-wireless" && (!current || ssidOf(c) !== current.name))
    readonly property var vpns: saved.filter(c => c.type === "vpn" || c.type === "wireguard")
    readonly property var others: wifiDev
        ? wifiDev.networks.values.filter(n => !n.connected && !n.known && n.name)
            .sort((a, b) => b.signalStrength - a.signalStrength).slice(0, 12)
        : []
    readonly property bool searching: !wifiDev || wifiDev.networks.values.length === 0

    function ssidOf(c) { return ssids[c.uuid] ?? c.name; }
    function nm(args) { Quickshell.execDetached(["nmcli"].concat(args)); refreshSoon.restart(); }

    function refresh() {
        savedProc.running = true;
        activeProc.running = true;
        if (wifiDev) { wifiInfoProc.dev = wifiDev.name; wifiInfoProc.running = true; }
        if (wiredDev) { wiredInfoProc.dev = wiredDev.name; wiredInfoProc.running = true; }
    }

    // nmcli -t escapa los ":" de los valores como "\:"
    function parseFields(text) {
        const out = {};
        text.split("\n").forEach(l => {
            const i = l.indexOf(":");
            if (i > 0) out[l.slice(0, i)] = l.slice(i + 1).replace(/\\:/g, ":");
        });
        return out;
    }
    // (sin lookbehind: el motor de QML no lo soporta y no partía la línea)
    function splitTerse(l) { return l.replace(/\\:/g, "\x01").split(":").map(f => f.replace(/\x01/g, ":")); }

    Timer { id: refreshSoon; interval: 1200; onTriggered: win.refresh() }
    Timer { interval: 4000; repeat: true; running: win.visible; onTriggered: win.refresh() }

    onVisibleChanged: Sys.scanUsers += visible ? 1 : -1

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.saved = text.split("\n").filter(l => l).map(l => {
                    const f = win.splitTerse(l);
                    return { name: f[0], uuid: f[1], type: f[2] };
                });
                const wifi = win.saved.filter(c => c.type === "802-11-wireless");
                if (!wifi.length) return;
                ssidProc.command = ["nmcli", "-t", "-f", "connection.uuid,802-11-wireless.ssid", "connection", "show"]
                    .concat(...wifi.map(c => ["uuid", c.uuid]));
                ssidProc.running = true;
            }
        }
    }
    // El SSID no sale en la lista: se pide por conexión y llega en bloques uuid/ssid
    Process {
        id: ssidProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                let uuid = "";
                text.split("\n").forEach(l => {
                    const f = win.parseFields(l);
                    if (f["connection.uuid"]) uuid = f["connection.uuid"];
                    else if (f["802-11-wireless.ssid"]) out[uuid] = f["802-11-wireless.ssid"];
                });
                win.ssids = out;
            }
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

    // ── piezas ──
    component SectionTitle: SectionLabel {
        Layout.topMargin: 14
        Layout.leftMargin: 4
        font.pointSize: 9
    }

    // caja redondeada que agrupa filas, como en Ajustes del Sistema
    component Group: Tile { Layout.fillWidth: true; padding: 0; spacing: 0 }

    component RowDivider: Divider { Layout.leftMargin: 12; Layout.rightMargin: 12 }

    // icono en un cuadrado de color, título y estado; los hijos van a la derecha
    component BadgeRow: RowLayout {
        id: br
        property string glyph: ""
        property color tint: Theme.accent
        property string title: ""
        property string subtitle: ""
        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 10
        Rectangle {
            implicitWidth: 28; implicitHeight: 28; radius: 7
            color: br.tint
            Glyph { anchors.centerIn: parent; width: 16; height: 16; name: br.glyph; level: 3; color: "white" }
        }
        ColumnLayout {
            spacing: 1
            Text { text: br.title; color: Theme.text; font.pointSize: 10.5; font.weight: Font.DemiBold }
            Text { text: br.subtitle; color: Theme.dim; font.pointSize: 9 }
        }
        Item { Layout.fillWidth: true }
    }

    // fila de red: nombre, estado en gris y, a la derecha, los hijos
    component NetRow: Rectangle {
        id: nr
        property string name: ""
        property string status: ""
        property alias clickable: area.enabled
        readonly property alias hovered: hover.hovered
        default property alias trailing: row.data
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 10
        color: hover.hovered ? Theme.tint(0.04) : "transparent"
        HoverHandler { id: hover }
        MouseArea { id: area; anchors.fill: parent; onClicked: nr.clicked() }
        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: 14; anchors.rightMargin: 12
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: nr.name
                color: Theme.text; font.pointSize: 10
                elide: Text.ElideRight
            }
            Text { visible: nr.status !== ""; text: nr.status; color: Theme.dim; font.pointSize: 9 }
        }
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

    // ── contenido ──
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
                text: I18n.tr("Network")
                color: Theme.text
                font.pointSize: 15
                font.weight: Font.Bold
                Layout.bottomMargin: 4
            }

            // ── Wi‑Fi ──
            Group {
                BadgeRow {
                    glyph: "wifi"
                    tint: Sys.wifiOn ? Theme.accent : Theme.tint(0.18)
                    title: "Wi‑Fi"
                    subtitle: !Sys.wifiOn ? I18n.tr("Off") : win.current ? I18n.tr("Connected") : I18n.tr("Not connected")
                    Switch { on: Sys.wifiOn; onToggled: Networking.wifiEnabled = !Networking.wifiEnabled }
                }

                RowDivider { visible: Sys.wifiOn && win.current !== null }

                // red actual
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
                    PillButton { text: win.showDetails ? I18n.tr("Hide Details") : I18n.tr("Details…"); onTapped: win.showDetails = !win.showDetails }
                }

                ColumnLayout {
                    visible: win.showDetails && Sys.wifiOn && win.current !== null
                    Layout.fillWidth: true
                    Layout.bottomMargin: 10
                    spacing: 0
                    RowDivider {}
                    InfoRow { label: I18n.tr("IP Address"); value: (win.wifiInfo["IP4.ADDRESS[1]"] ?? "").split("/")[0] }
                    InfoRow { label: I18n.tr("Subnet"); value: (win.wifiInfo["IP4.ADDRESS[1]"] ?? "").includes("/") ? "/" + win.wifiInfo["IP4.ADDRESS[1]"].split("/")[1] : "" }
                    InfoRow { label: "Router"; value: win.wifiInfo["IP4.GATEWAY"] ?? "" }
                    InfoRow { label: "DNS"; value: [1, 2, 3].map(i => win.wifiInfo["IP4.DNS[" + i + "]"]).filter(x => x).join(", ") }
                    InfoRow { label: I18n.tr("IPv6 Address"); value: (win.wifiInfo["IP6.ADDRESS[1]"] ?? "").split("/")[0] }
                    InfoRow { label: I18n.tr("Wi‑Fi Address"); value: win.wifiInfo["GENERAL.HWADDR"] ?? "" }
                    InfoRow { label: I18n.tr("Signal"); value: win.current ? Math.round(win.current.signalStrength * 100) + " %" : "" }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 6
                        spacing: 8
                        Item { Layout.fillWidth: true }
                        PillButton { text: I18n.tr("Disconnect"); onTapped: { win.current.disconnect(); win.showDetails = false; } }
                        PillButton {
                            text: I18n.tr("Forget This Network…")
                            danger: true
                            onTapped: {
                                const c = win.saved.find(s => s.type === "802-11-wireless" && win.ssidOf(s) === win.current.name);
                                if (c) win.nm(["connection", "delete", "uuid", c.uuid]);
                                win.showDetails = false;
                            }
                        }
                    }
                }
            }

            // ── redes conocidas ──
            SectionTitle { visible: Sys.wifiOn && win.savedWifi.length > 0; text: I18n.tr("Known Networks") }
            Group {
                visible: Sys.wifiOn && win.savedWifi.length > 0
                Repeater {
                    model: win.savedWifi
                    delegate: ColumnLayout {
                        id: known
                        required property var modelData
                        required property int index
                        readonly property string ssid: win.ssidOf(modelData)
                        readonly property var live: win.wifiDev ? win.wifiDev.networks.values.find(n => n.name === ssid) ?? null : null
                        Layout.fillWidth: true
                        spacing: 0
                        RowDivider { visible: known.index > 0 }
                        NetRow {
                            id: knownRow
                            name: known.ssid
                            status: known.live ? "" : I18n.tr("Not in range")
                            // fuera de alcance no hay a qué conectarse (olvidarla sí se puede)
                            clickable: known.live !== null
                            onClicked: known.live.connect()
                            Glyph {
                                visible: known.live !== null
                                name: "wifi"
                                level: known.live ? Sys.wifiBars(known.live.signalStrength) : 0
                                color: Theme.text
                            }
                            PillButton {
                                visible: knownRow.hovered
                                text: I18n.tr("Forget")
                                danger: true
                                onTapped: win.nm(["connection", "delete", "uuid", known.modelData.uuid])
                            }
                        }
                    }
                }
            }

            // ── otras redes ──
            SectionTitle { visible: Sys.wifiOn && (win.searching || win.others.length > 0); text: I18n.tr("Other Networks") }
            Group {
                visible: Sys.wifiOn && (win.searching || win.others.length > 0)
                Text {
                    visible: win.searching
                    Layout.margins: 14
                    text: I18n.tr("Searching…")
                    color: Theme.dim; font.pointSize: 9.5
                }
                Repeater {
                    // ScriptModel y no un array: reaprovecha las filas cuando cambia la
                    // señal, así no se pierde la contraseña a medio escribir
                    model: ScriptModel { values: win.others }
                    delegate: ColumnLayout {
                        id: other
                        required property var modelData
                        required property int index
                        readonly property bool secured: modelData.security !== WifiSecurityType.Open
                        readonly property bool asking: win.askingFor === modelData.name
                        Layout.fillWidth: true
                        spacing: 0
                        RowDivider { visible: other.index > 0 }
                        NetRow {
                            name: other.modelData.name
                            status: other.modelData.stateChanging ? I18n.tr("Connecting…") : ""
                            onClicked: {
                                if (!other.secured) other.modelData.connect();
                                else win.askingFor = other.asking ? "" : other.modelData.name;
                            }
                            Glyph { visible: other.secured; name: "lock"; color: Theme.dim }
                            Glyph { name: "wifi"; level: Sys.wifiBars(other.modelData.signalStrength); color: Theme.text }
                        }
                        // contraseña para una red protegida nueva
                        RowLayout {
                            visible: other.asking
                            Layout.fillWidth: true
                            Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 10
                            spacing: 8
                            PasswordField {
                                id: pass
                                Layout.fillWidth: true
                                onSubmitted: psk => {
                                    other.modelData.connectWithPsk(psk);
                                    win.askingFor = "";
                                }
                            }
                            PillButton { text: I18n.tr("Join"); onTapped: pass.submit() }
                        }
                    }
                }
            }

            // ── Ethernet ──
            SectionTitle { visible: win.wiredDev !== null; text: "Ethernet" }
            Group {
                visible: win.wiredDev !== null
                BadgeRow {
                    glyph: "ethernet"
                    tint: Sys.wiredUp ? "#30d158" : Theme.tint(0.18)
                    title: "Ethernet"
                    subtitle: Sys.wiredUp ? I18n.tr("Connected") : I18n.tr("Cable unplugged")
                }
                ColumnLayout {
                    visible: Sys.wiredUp
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    spacing: 0
                    RowDivider {}
                    InfoRow { label: I18n.tr("IP Address"); value: (win.wiredInfo["IP4.ADDRESS[1]"] ?? "").split("/")[0] }
                    InfoRow { label: "Router"; value: win.wiredInfo["IP4.GATEWAY"] ?? "" }
                    InfoRow { label: I18n.tr("Hardware Address"); value: win.wiredInfo["GENERAL.HWADDR"] ?? "" }
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
                        RowDivider { visible: vpn.index > 0 }
                        BadgeRow {
                            glyph: "lock"
                            tint: vpn.active ? Theme.accent : Theme.tint(0.18)
                            title: vpn.modelData.name
                            subtitle: vpn.active ? I18n.tr("Connected") : I18n.tr("Not connected")
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
