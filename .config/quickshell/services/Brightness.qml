// Screen brightness (reads /sys, changes with brightnessctl). There's only something
// to control if a backlit panel exists (/sys/class/backlight):
// on a desktop there's none and `available` stays false, so the bar, the
// notification panel and the OSD hide brightness.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Panel from /sys/class/backlight, by type raw > platform > firmware (so a dead
    // acpi_video0 isn't picked if there's intel_backlight); "" if there's none
    property string device: ""
    readonly property bool available: device !== ""
    property int percent: 0
    // Icon by level (three ranges, like the volume one)
    readonly property string icon: ["󰃞", "󰃟", "󰃠"][Math.min(2, Math.floor(percent / 100 * 3))]

    function raise() { set(percent + 5); }
    function lower() { set(percent - 5); }

    // Value (in %) still to apply: while dragging, values arrive while
    // brightnessctl is still running; the last one is kept and applied when it finishes
    property int pending: -1

    function set(p) {
        if (!available)
            return;
        // percent changes right away, so the bar follows the mouse and key presses add up
        percent = pending = Math.max(1, Math.min(100, Math.round(p)));
        if (!setter.running)
            apply();
    }

    function apply() {
        // -d: always the detected panel (without it brightnessctl could pick an LED)
        setter.command = ["brightnessctl", "-d", device.split("/").pop(), "--min-value=1", "set", pending + "%"];
        pending = -1;
        setter.running = true;
    }

    // For Hyprland's brightness keys: qs ipc call brightness up/down.
    // step: n steps of 5 % at once, up or down (macshell's wheel);
    // returns whether there's a panel, so macshell knows if it has to change it on its own
    IpcHandler {
        target: "brightness"
        function up(): void { root.raise(); }
        function down(): void { root.lower(); }
        function step(up: bool, n: int): bool {
            root.set(root.percent + (up ? 5 : -5) * n);
            return root.available;
        }
    }

    // Looks for the panel once at start-up (the same script macshell uses)
    Process {
        running: true
        command: [Quickshell.shellDir + "/scripts/backlight-device"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    Process {
        id: setter
        onExited: root.pending >= 0 ? root.apply() : current.reload()
    }

    // sysfs can't be watched, but the kernel reports every panel change with a
    // "change" uevent (also when someone else changes it, e.g. brightnessctl by hand):
    // it is re-read on every udevadm line instead of polling every few seconds
    Process {
        running: root.available
        command: ["udevadm", "monitor", "-k", "-s", "backlight"]
        stdout: SplitParser {
            // Not while a change is being applied (when dragging, percent is ahead);
            // setter re-reads when done
            onRead: if (!setter.running) current.reload()
        }
    }

    // blockLoading: otherwise `current` may load before `max`, percent
    // would stay at 0 and an up key would set brightness to 5 %
    FileView {
        id: max
        path: root.available ? root.device + "/max_brightness" : ""
        blockLoading: true
    }
    FileView {
        id: current
        path: root.available ? root.device + "/brightness" : ""
        onLoaded: {
            const m = Number(max.text());
            if (m > 0)
                root.percent = Math.round(100 * Number(text()) / m);
        }
    }
}
