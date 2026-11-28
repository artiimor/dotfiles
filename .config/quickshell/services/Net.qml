// Network: which connection there is (wifi or cable), the signal, the IP and the
// download/upload speed (measuring how many bytes go through the interface each second,
// only while something shows it: measuring, the bar tooltip).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiNetwork: wifi?.networks.values.find(n => n.connected) ?? null

    // Depending on the backend, the signal comes as 0–1 or 0–100. It's var and not int: on
    // reload, the half-destroyed old Net may give undefined and an int warns
    readonly property var signal: {
        const s = wifiNetwork?.signalStrength ?? 0;
        return Math.round(s > 1 ? s : s * 100);
    }

    // Interface in use (cable wins if both are up)
    readonly property string iface: wired?.name ?? wifi?.name ?? ""

    property string ip: ""       // "192.168.1.10/24"
    property real down: 0        // bytes/s
    property real up: 0
    property bool measuring: false

    // "1.2 MB/s"
    function speed(bytes) {
        const units = ["B/s", "kB/s", "MB/s", "GB/s"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) {
            bytes /= 1000;
            i++;
        }
        return (i === 0 ? Math.round(bytes) : bytes.toFixed(1)) + " " + units[i];
    }

    onIfaceChanged: {
        ip = "";
        _last = null;
        down = up = 0;
        // exec kills the read of the previous interface, if still running
        if (iface)
            readIp();
        else
            ipProc.running = false;
    }

    // ── IP ────────────────────────────────────────────────
    function readIp() {
        ipProc.exec(["ip", "-4", "-br", "addr", "show", "dev", iface]);
    }

    Process {
        id: ipProc
        stdout: StdioCollector {
            // "wlan0   UP   192.168.1.10/24"
            onStreamFinished: root.ip = text.trim().split(/\s+/)[2] ?? ""
        }
    }

    // The IP can change without changing interface (DHCP): re-read every 5 min
    // and when it starts being shown, or every 2 s while there's none (just connected)
    Timer {
        interval: root.ip ? 300000 : 2000
        running: root.iface !== ""
        repeat: true
        onTriggered: root.readIp()
    }

    // ── Velocidad ─────────────────────────────────────────
    property var _last: null

    // When measuring stops the last sample is forgotten: otherwise the first measurement
    // next time would be the average of the whole unwatched period
    onMeasuringChanged: {
        _last = null;
        down = up = 0;
        if (measuring && iface)
            readIp();
    }

    Timer {
        interval: 1000
        running: root.measuring && root.iface !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            rx.reload();
            tx.reload();
            const now = Date.now();
            const r = Number(rx.text()), t = Number(tx.text());
            if (root._last) {
                const dt = (now - root._last.time) / 1000;
                root.down = Math.max(0, (r - root._last.rx) / dt);
                root.up = Math.max(0, (t - root._last.tx) / dt);
            }
            root._last = { time: now, rx: r, tx: t };
        }
    }

    FileView {
        id: rx
        path: root.iface ? `/sys/class/net/${root.iface}/statistics/rx_bytes` : ""
        blockLoading: true
    }
    FileView {
        id: tx
        path: root.iface ? `/sys/class/net/${root.iface}/statistics/tx_bytes` : ""
        blockLoading: true
    }
}
