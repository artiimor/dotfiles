pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// System state shared by the bar and its popups.
Singleton {
    id: sys

    // ── red ──
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wiredUp: wiredDevice ? wiredDevice.connected : false
    readonly property var wifiNetwork: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) ?? null : null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property int wifiLevel: wifiNetwork ? wifiBars(wifiNetwork.signalStrength) : 0
    // Wi‑Fi icon bars (1–3) for a signal from 0 to 1
    function wifiBars(s) { return Math.max(1, Math.ceil(s * 3)); }
    // The Wi‑Fi scan stays active while something showing the network list
    // is open (Wi‑Fi popup, Network window): each one adds 1 while visible
    property int scanUsers: 0
    Binding {
        when: sys.wifiDevice !== null
        target: sys.wifiDevice
        property: "scannerEnabled"
        value: sys.scanUsers > 0
    }

    // ── bluetooth ──
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt ? bt.enabled : false
    readonly property var btConnected: bt ? bt.devices.values.filter(d => d.connected) : []

    // ── audio ──
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: sys.sink ? [sys.sink] : [] }
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    function setVolume(v) {
        if (!sink || !sink.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = v;
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }
    // bar wheel: ±d with the same rule as the normal bar (Theme.wheelStep from the
    // root config): going up it stops at 100 % and doesn't touch a volume already above 100 %
    function stepVolume(d) {
        if (!sink || !sink.audio) return;
        const v = sink.audio.volume;
        sink.audio.volume = d > 0 ? (v < 1 ? Math.min(1, v + d) : v) : Math.max(0, v + d);
    }
    // display name of a Pipewire node
    function nodeName(n) { return n ? (n.description || n.nickname || n.name) : ""; }

    // ── media ──
    // playerctld is a playerctl proxy, not a player: out (like in the normal bar)
    readonly property var player: {
        const ps = Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"));
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }

    // ── battery ──
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery
    readonly property real batteryFraction: battery ? battery.percentage : 1
    readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging
                                                || battery.state === UPowerDeviceState.FullyCharged
                                                || battery.state === UPowerDeviceState.PendingCharge)

    // ── brightness (brightnessctl, goes through logind) ──
    // Only with a backlit panel (laptop); on a desktop there is no
    // /sys/class/backlight and the Control Center hides the slider. The panel is picked by
    // the same script the normal bar uses (scripts/backlight-device from the root
    // config) and passed to brightnessctl with -d (without it, it could pick an LED).
    property string backlightDevice: ""          // p. ej. "intel_backlight"
    readonly property bool hasBacklight: backlightDevice !== ""
    property real brightness: 1
    property real _pending: -1
    function setBrightness(v) {
        if (!hasBacklight) return;
        brightness = Math.max(0.02, Math.min(1, v));
        _pending = brightness;
        if (!setProc.running) _flush();
    }
    function _flush() {
        if (_pending < 0) return;
        setProc.command = ["brightnessctl", "-q", "-d", backlightDevice, "set", Math.round(_pending * 100) + "%"];
        _pending = -1;
        setProc.running = true;
    }
    Process { id: setProc; onExited: sys._flush() }
    Process {
        running: true
        command: [Quickshell.shellDir + "/../scripts/backlight-device"]
        stdout: StdioCollector {
            onStreamFinished: {
                sys.backlightDevice = text.trim().split("/").pop();
                sys.refreshBrightness();
            }
        }
    }
    Process {
        id: getProc
        command: ["brightnessctl", "-m", "-d", sys.backlightDevice]
        stdout: StdioCollector {
            // "<panel>,backlight,<value>,<percent>%,<max>"
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 4) sys.brightness = parseInt(f[3]) / 100;
            }
        }
    }
    function refreshBrightness() { if (hasBacklight && !getProc.running) getProc.running = true; }

    // Bar wheel: 5 % steps through the root config's Brightness
    // (`qs ipc call brightness step <up> <n>`), so its OSD shows and both stay in
    // sync. Steps arriving while a call is running are merged into the
    // next one. If the root config doesn't answer "true" (not running, or no panel), it is
    // changed here directly.
    property int _brightSteps: 0
    function stepBrightness(n) {
        if (!hasBacklight) return;
        _brightSteps += n;
        if (!brightIpc.running) _sendBrightSteps();
    }
    function _sendBrightSteps() {
        if (_brightSteps === 0) { brightRefresh.restart(); return; }
        brightIpc.steps = _brightSteps;
        _brightSteps = 0;
        // up/down and how many steps separately: a negative number would be taken as an option
        brightIpc.command = ["qs", "ipc", "call", "brightness", "step",
            String(brightIpc.steps > 0), String(Math.abs(brightIpc.steps))];
        brightIpc.running = true;
    }
    Process {
        id: brightIpc
        property int steps: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "true") sys.setBrightness(sys.brightness + 0.05 * brightIpc.steps);
                sys._sendBrightSteps();
            }
        }
    }
    // the root config's brightnessctl takes a moment to apply the value
    Timer { id: brightRefresh; interval: 300; onTriggered: sys.refreshBrightness() }

    // ── night light (Night Shift) ──
    // Same script as the normal bar (scripts/nightlight.sh from the root config, talks
    // to hyprsunset and saves manual off in $XDG_RUNTIME_DIR): the state lives in
    // hyprsunset, so there's nothing to sync.
    readonly property string nightScript: Quickshell.shellDir + "/../scripts/nightlight.sh"
    property string nightState: "unavailable"    // "on" | "off" | "unavailable"
    readonly property bool nightOn: nightState === "on"
    // Each action bumps _nightGen: a read started earlier is discarded (it would bring the
    // old state) and, if another was requested while it ran, it repeats when done
    property int _nightGen: 0
    property bool _nightAgain: false
    function toggleNight() {
        if (nightAct.running || nightState === "unavailable") return;
        _nightGen++;
        nightState = nightOn ? "off" : "on";   // optimistic; confirmed on re-read
        nightAct.exec([nightScript, "toggle"]);
    }
    function refreshNight() {
        if (nightGet.running) { _nightAgain = true; return; }
        nightGet.gen = _nightGen;
        nightGet.running = true;
    }
    Process { id: nightAct; onExited: sys.refreshNight() }
    Process {
        id: nightGet
        property int gen: 0
        command: [sys.nightScript]
        stdout: StdioCollector {
            onStreamFinished: {
                if (nightGet.gen !== sys._nightGen) return;
                try { sys.nightState = JSON.parse(text)["class"]; } catch (e) {}
            }
        }
        onExited: if (sys._nightAgain) { sys._nightAgain = false; sys.refreshNight(); }
    }
    // No polling: read at start-up (onCompleted, below) and when opening the
    // display panel and the control center, the only ones showing it (shell.qml)

    // ── increase contrast ──
    // wasdjy-contrast (theme scripts) saves the state in a file that Theme watches:
    // here it's only launched, the state is Theme.contrast
    function toggleContrast() {
        if (!contrastAct.running)
            contrastAct.exec([Quickshell.env("HOME") + "/.local/share/wasdjy/bin/wasdjy-contrast", "toggle"]);
    }
    Process { id: contrastAct }

    // ── caffeine (no automatic suspend) ──
    // The inhibitor belongs to the root config (services/Idle.qml, which keeps running in
    // Mac Mode): no other one is created here. It is toggled with `qs ipc call idle toggle` and the state
    // is always queried with `qs ipc call idle get`: at start-up, after each change from
    // here and when the file Idle rewrites on every change changes (it only serves as a
    // notice). If the root config isn't running, get doesn't answer "true" and the button shows off.
    property bool caffeine: false
    property bool _caffeineAgain: false
    function toggleCaffeine() { if (!idleToggle.running) idleToggle.running = true; }
    function syncCaffeine() {
        if (idleGet.running) { _caffeineAgain = true; return; }
        idleGet.running = true;
    }
    Process {
        id: idleToggle
        command: ["qs", "ipc", "call", "idle", "toggle"]
        onExited: sys.syncCaffeine()
    }
    Process {
        id: idleGet
        command: ["qs", "ipc", "call", "idle", "get"]
        stdout: StdioCollector { onStreamFinished: sys.caffeine = text.trim() === "true" }
        onExited: if (sys._caffeineAgain) { sys._caffeineAgain = false; sys.syncCaffeine(); }
    }
    property FileView _idleFile: FileView {
        // without XDG_RUNTIME_DIR there's no file (Idle doesn't write it either)
        path: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/qs-idle-inhibited" : ""
        watchChanges: path !== ""
        preload: false
        printErrors: false
        onFileChanged: sys.syncCaffeine()
    }
    Component.onCompleted: { syncCaffeine(); refreshNight(); }

    // ── memory and temperature (like the root config's services/SysStats.qml) ──
    property real memUsed: 0     // GiB
    property real memTotal: 0    // GiB
    property int temp: 0         // °C
    readonly property int tempCritical: 80
    // every 15 s, or every 2 s while the system popup is visible (set by shell.qml)
    property bool statsFast: false
    function refreshStats() { meminfo.reload(); if (thermal.path !== "") thermal.reload(); }
    onStatsFastChanged: if (statsFast) refreshStats()
    Timer {
        interval: sys.statsFast ? 2000 : 15000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: sys.refreshStats()
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const get = key => Number(text().match(new RegExp(key + ":\\s+(\\d+)"))[1]) / 1048576;
            sys.memTotal = get("MemTotal");
            sys.memUsed = sys.memTotal - get("MemAvailable");
        }
    }
    // CPU sensor: coretemp / k10temp / zenpower, else x86_pkg_temp, else thermal_zone0
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
        stdout: StdioCollector { onStreamFinished: thermal.path = text.trim() }
    }
    FileView {
        id: thermal
        path: ""
        printErrors: false
        onLoaded: sys.temp = Math.round(Number(text()) / 1000)
    }

    // ── utilidades ──
    function duration(secs) {
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }
}
