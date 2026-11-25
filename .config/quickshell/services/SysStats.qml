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

    // Sensor de la CPU: hwmon de coretemp (Intel) o k10temp/zenpower (AMD); si no,
    // la zona térmica x86_pkg_temp y, como último recurso, thermal_zone0 (suele ser
    // acpitz, que no es la CPU). Los números de hwmonN cambian entre arranques,
    // así que se busca al iniciar en vez de fijar una ruta.
    Process {
        running: true
        command: ["sh", "-c", `
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name" 2>/dev/null)" in
                    coretemp|k10temp|zenpower|cpu_thermal)
                        [ -r "$h/temp1_input" ] && { echo "$h/temp1_input"; exit; } ;;
                esac
            done
            for z in /sys/class/thermal/thermal_zone*; do
                [ "$(cat "$z/type" 2>/dev/null)" = x86_pkg_temp ] && { echo "$z/temp"; exit; }
            done
            [ -r /sys/class/thermal/thermal_zone0/temp ] && echo /sys/class/thermal/thermal_zone0/temp`]
        stdout: StdioCollector {
            onStreamFinished: thermal.path = text.trim()
        }
    }

    FileView {
        id: thermal
        path: ""
        onLoaded: root.temp = Math.round(Number(text()) / 1000)
    }
}
