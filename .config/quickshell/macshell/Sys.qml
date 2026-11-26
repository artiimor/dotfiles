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

    // ── multimedia ──
    readonly property var player: {
        const ps = Mpris.players.values;
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

    // ── utilidades ──
    function duration(secs) {
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }
}
