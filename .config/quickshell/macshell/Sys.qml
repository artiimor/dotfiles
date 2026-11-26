pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// Estado del sistema compartido por la barra y sus popups.
Singleton {
    id: sys

    // ── red ──
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wiredUp: wiredDevice ? wiredDevice.connected : false
    readonly property var wifiNetwork: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) ?? null : null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property int wifiLevel: wifiNetwork ? wifiBars(wifiNetwork.signalStrength) : 0
    // barras del icono Wi‑Fi (1–3) para una señal de 0 a 1
    function wifiBars(s) { return Math.max(1, Math.ceil(s * 3)); }
    // El escaneo Wi‑Fi sigue activo mientras haya abierto algo que muestre la lista
    // de redes (popup Wi‑Fi, ventana Network): cada uno suma 1 mientras se ve
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
    // rueda de la barra: ±d con la misma regla que la barra normal (Theme.wheelStep de la
    // config raíz): subiendo se para en 100 % y no toca un volumen que ya pase de 100 %
    function stepVolume(d) {
        if (!sink || !sink.audio) return;
        const v = sink.audio.volume;
        sink.audio.volume = d > 0 ? (v < 1 ? Math.min(1, v + d) : v) : Math.max(0, v + d);
    }
    // nombre visible de un nodo de Pipewire
    function nodeName(n) { return n ? (n.description || n.nickname || n.name) : ""; }

    // ── multimedia ──
    // playerctld es un proxy de playerctl, no un reproductor: fuera (como en la barra normal)
    readonly property var player: {
        const ps = Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"));
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }

    // ── batería ──
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery
    readonly property real batteryFraction: battery ? battery.percentage : 1
    readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging
                                                || battery.state === UPowerDeviceState.FullyCharged
                                                || battery.state === UPowerDeviceState.PendingCharge)

    // ── brillo (brightnessctl, pasa por logind) ──
    // Solo con panel retroiluminado (portátil); en un sobremesa no hay
    // /sys/class/backlight y el Control Center esconde el slider.
    // -c backlight: sin él brightnessctl podría coger un LED del teclado.
    property bool hasBacklight: false
    property real brightness: 1
    property real _pending: -1
    function setBrightness(v) {
        if (!hasBacklight) return;
        brightness = Math.max(0.02, v);
        _pending = brightness;
        if (!setProc.running) _flush();
    }
    function _flush() {
        if (_pending < 0) return;
        setProc.command = ["brightnessctl", "-q", "-c", "backlight", "set", Math.round(_pending * 100) + "%"];
        _pending = -1;
        setProc.running = true;
    }
    Process { id: setProc; onExited: sys._flush() }
    Process {
        id: getProc
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                sys.hasBacklight = f.length >= 4 && f[1] === "backlight";
                if (sys.hasBacklight) sys.brightness = parseInt(f[3]) / 100;
            }
        }
    }
    function refreshBrightness() { getProc.running = true; }
    Component.onCompleted: refreshBrightness()

    // Rueda de la barra: ±5 % a través del Brightness de la config raíz (`qs ipc call
    // brightness up|down`, lo mismo que las teclas de brillo), así sale su OSD y los dos
    // quedan de acuerdo. Si la config raíz no responde, se cambia aquí directamente.
    // Los pasos se acumulan mientras corre una llamada y se aplican de uno en uno.
    property int _brightSteps: 0
    function stepBrightness(dir) {
        if (!hasBacklight) return;
        _brightSteps += dir > 0 ? 1 : -1;
        if (!brightIpc.running) _nextBrightStep();
    }
    function _nextBrightStep() {
        if (_brightSteps === 0) { brightRefresh.restart(); return; }
        const up = _brightSteps > 0;
        _brightSteps += up ? -1 : 1;
        brightIpc.up = up;
        brightIpc.command = ["qs", "ipc", "call", "brightness", up ? "up" : "down"];
        brightIpc.running = true;
    }
    Process {
        id: brightIpc
        property bool up: true
        onExited: code => {
            if (code !== 0) sys.setBrightness(sys.brightness + (up ? 0.05 : -0.05));
            sys._nextBrightStep();
        }
    }
    // brightnessctl de la config raíz tarda un poco en aplicar el valor
    Timer { id: brightRefresh; interval: 300; onTriggered: sys.refreshBrightness() }

    // ── luz nocturna (Night Shift) ──
    // Mismo script que la barra normal (scripts/nightlight.sh de la config raíz, habla
    // con hyprsunset y guarda el apagado manual en $XDG_RUNTIME_DIR): el estado vive en
    // hyprsunset, así que no hay nada que sincronizar.
    readonly property string nightScript: Quickshell.shellDir + "/../scripts/nightlight.sh"
    property string nightState: "unavailable"    // "on" | "off" | "unavailable"
    property string nightTooltip: ""
    readonly property bool nightOn: nightState === "on"
    function toggleNight() {
        if (nightAct.running || nightState === "unavailable") return;
        nightState = nightOn ? "off" : "on";   // optimista; se confirma al releer
        nightAct.exec([nightScript, "toggle"]);
    }
    function refreshNight() { if (!nightGet.running) nightGet.running = true; }
    Process { id: nightAct; onExited: sys.refreshNight() }
    Process {
        id: nightGet
        command: [sys.nightScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    sys.nightState = j["class"];
                    sys.nightTooltip = j.tooltip;
                } catch (e) {}
            }
        }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: sys.refreshNight() }

    // ── cafeína (sin suspensión automática) ──
    // El inhibidor lo tiene la config raíz (services/Idle.qml, que sigue en marcha en el
    // Modo Mac): aquí no se crea otro. Se cambia con `qs ipc call idle toggle` y el estado
    // se lee del archivo que Idle escribe en cada cambio. Si la config raíz no está, la
    // llamada falla, el archivo no cambia y el botón sigue diciendo la verdad.
    property bool caffeine: false
    function toggleCaffeine() { Quickshell.execDetached(["qs", "ipc", "call", "idle", "toggle"]); }
    property bool _idleOk: false
    property FileView _idleFile: FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-idle-inhibited"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { sys._idleOk = true; sys.caffeine = text().trim() === "1"; }
        onLoadFailed: { sys._idleOk = false; sys.caffeine = false; }
    }
    // hasta que la config raíz crea el archivo no hay nada que vigilar: se reintenta
    Timer { interval: 5000; repeat: true; running: !sys._idleOk; onTriggered: sys._idleFile.reload() }

    // ── memoria y temperatura (como services/SysStats.qml de la config raíz) ──
    property real memUsed: 0     // GiB
    property real memTotal: 0    // GiB
    property int temp: 0         // °C
    readonly property int tempCritical: 80
    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { meminfo.reload(); if (thermal.path !== "") thermal.reload(); }
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
    // sensor de la CPU: coretemp / k10temp / zenpower, si no x86_pkg_temp y si no thermal_zone0
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
