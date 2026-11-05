// Red: qué conexión hay (wifi o cable), la señal, la IP y la velocidad de
// bajada/subida (midiendo cuántos bytes pasan por la interfaz cada 2 s).
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

    // Según el backend, la señal viene como 0–1 o 0–100
    readonly property int signal: {
        const s = wifiNetwork?.signalStrength ?? 0;
        return Math.round(s > 1 ? s : s * 100);
    }

    // Interfaz en uso (el cable manda si están los dos)
    readonly property string iface: wired?.name ?? wifi?.name ?? ""

    property string ip: ""       // "192.168.1.64/24"
    property real down: 0        // bytes/s
    property real up: 0

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
        if (iface)
            ipProc.running = true;
    }

    // ── IP ────────────────────────────────────────────────
    Process {
        id: ipProc
        command: ["ip", "-4", "-br", "addr", "show", "dev", root.iface]
        stdout: StdioCollector {
            // "wlan0   UP   192.168.1.64/24"
            onStreamFinished: root.ip = text.trim().split(/\s+/)[2] ?? ""
        }
    }

    // ── Velocidad ─────────────────────────────────────────
    property var _last: null

    Timer {
        interval: 2000
        running: root.iface !== ""
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
            // La IP puede cambiar sin cambiar de interfaz (DHCP); se revisa de vez en cuando
            if (!root.ip)
                ipProc.running = true;
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
