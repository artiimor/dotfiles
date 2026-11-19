// Memoria y temperatura, leídas de /proc y /sys cada 3 segundos.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real memUsed: 0     // GiB
    property real memTotal: 0    // GiB
    property int temp: 0         // °C
    readonly property int tempCritical: 80

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            thermal.reload();
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
