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
    // /sys/class/backlight y el Control Center esconde el slider. El panel lo elige
    // el mismo script que usa la barra normal (scripts/backlight-device de la config
    // raíz) y se le pasa a brightnessctl con -d (sin él podría coger un LED).
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
            // "<panel>,backlight,<valor>,<porcentaje>%,<máximo>"
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 4) sys.brightness = parseInt(f[3]) / 100;
            }
        }
    }
    function refreshBrightness() { if (hasBacklight && !getProc.running) getProc.running = true; }

    // Rueda de la barra: pasos de 5 % a través del Brightness de la config raíz
    // (`qs ipc call brightness step <subir> <n>`), así sale su OSD y los dos quedan de
    // acuerdo. Los pasos que llegan mientras corre una llamada se juntan en la
    // siguiente. Si la config raíz no responde "true" (no está, o no ve panel), se
    // cambia aquí directamente.
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
        // sube/baja y cuántos pasos por separado: un número negativo lo tomaría por opción
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
    // brightnessctl de la config raíz tarda un poco en aplicar el valor
    Timer { id: brightRefresh; interval: 300; onTriggered: sys.refreshBrightness() }

    // ── luz nocturna (Night Shift) ──
    // Mismo script que la barra normal (scripts/nightlight.sh de la config raíz, habla
    // con hyprsunset y guarda el apagado manual en $XDG_RUNTIME_DIR): el estado vive en
    // hyprsunset, así que no hay nada que sincronizar.
    readonly property string nightScript: Quickshell.shellDir + "/../scripts/nightlight.sh"
    property string nightState: "unavailable"    // "on" | "off" | "unavailable"
    readonly property bool nightOn: nightState === "on"
    // Cada acción sube _nightGen: una lectura empezada antes se descarta (traería el
    // estado viejo) y, si se pidió otra mientras corría, se repite al terminar
    property int _nightGen: 0
    property bool _nightAgain: false
    function toggleNight() {
        if (nightAct.running || nightState === "unavailable") return;
        _nightGen++;
        nightState = nightOn ? "off" : "on";   // optimista; se confirma al releer
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
    // Sin sondeo: se lee al arrancar (onCompleted, abajo) y al abrir el panel de
    // pantalla y el centro de control, los únicos que lo enseñan (shell.qml)

    // ── aumentar contraste ──
    // contrast-set (scripts de temas) guarda el estado en un archivo que Theme vigila:
    // aquí solo se lanza, el estado es Theme.contrast
    function toggleContrast() {
        if (!contrastAct.running)
            contrastAct.exec([Quickshell.env("HOME") + "/.config/themes/contrast-set", "toggle"]);
    }
    Process { id: contrastAct }

    // ── cafeína (sin suspensión automática) ──
    // El inhibidor lo tiene la config raíz (services/Idle.qml, que sigue en marcha en el
    // Modo Mac): aquí no se crea otro. Se cambia con `qs ipc call idle toggle` y el estado
    // se pregunta siempre con `qs ipc call idle get`: al arrancar, tras cada cambio desde
    // aquí y cuando cambia el archivo que Idle reescribe en cada cambio (solo sirve de
    // aviso). Si la config raíz no está, get no contesta "true" y el botón sale apagado.
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
        // sin XDG_RUNTIME_DIR no hay archivo (Idle tampoco lo escribe)
        path: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/qs-idle-inhibited" : ""
        watchChanges: path !== ""
        preload: false
        printErrors: false
        onFileChanged: sys.syncCaffeine()
    }
    Component.onCompleted: { syncCaffeine(); refreshNight(); }

    // ── memoria y temperatura (como services/SysStats.qml de la config raíz) ──
    property real memUsed: 0     // GiB
    property real memTotal: 0    // GiB
    property int temp: 0         // °C
    readonly property int tempCritical: 80
    // cada 15 s, o cada 2 s mientras se ve el popup de sistema (lo pone shell.qml)
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
