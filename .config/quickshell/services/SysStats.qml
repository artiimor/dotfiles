// CPU, memoria y temperatura, leídos de /proc y /sys cada 3 segundos.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpu: 0          // %
    property real memUsed: 0     // GiB
    property real memTotal: 0    // GiB
    property int temp: 0         // °C
    readonly property int tempCritical: 80

    property var _lastCpu: null

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            thermal.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            // Primera línea: "cpu  user nice system idle iowait irq softirq ..."
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root._lastCpu) {
                const dt = total - root._lastCpu.total;
                const di = idle - root._lastCpu.idle;
                if (dt > 0)
                    root.cpu = Math.round(100 * (dt - di) / dt);
            }
            root._lastCpu = { total, idle };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const get = key => Number(text().match(new RegExp(key + ":\\s+(\\d+)"))[1]) / 1048576;
            root.memTotal = get("MemTotal");
            root.memUsed = root.memTotal - get("MemAvailable");
        }
    }

    FileView {
        id: thermal
        path: "/sys/class/thermal/thermal_zone0/temp"
        onLoaded: root.temp = Math.round(Number(text()) / 1000)
    }
}
