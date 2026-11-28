// Memory and temperature, read from /proc and /sys every 15 seconds, or every 2
// while visible (fast: the bar drawer open, set by Status.qml).
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
    property bool fast: false

    function refresh() {
        meminfo.reload();
        thermal.reload();
    }

    // When the drawer opens it reads right away, without waiting for the next tick
    onFastChanged: if (fast) refresh()

    Timer {
        interval: root.fast ? 2000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
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

    // CPU sensor: coretemp hwmon (Intel) or k10temp/zenpower (AMD); otherwise
    // the x86_pkg_temp thermal zone and, as a last resort, thermal_zone0 (usually
    // acpitz, which isn't the CPU). hwmonN numbers change between boots,
    // so it's looked up at start-up instead of hardcoding a path.
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
