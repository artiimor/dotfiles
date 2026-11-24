pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// Shared system state for the bar and its popups.
Singleton {
    id: sys

    // ── network ──
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wiredUp: wiredDevice ? wiredDevice.connected : false
    readonly property var wifiNetwork: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) ?? null : null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property int wifiLevel: wifiNetwork ? Math.max(1, Math.ceil(wifiNetwork.signalStrength * 3)) : 0
    // Wi-Fi scanning stays on while anything showing the network list is open
    // (Wi-Fi popup, Network window): each one adds 1 while it's shown
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

    // ── media ──
    readonly property var player: {
        const ps = Mpris.players.values;
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
    property real brightness: 1
    property real _pending: -1
    function setBrightness(v) {
        brightness = Math.max(0.02, v);
        _pending = brightness;
        if (!setProc.running) _flush();
    }
    function _flush() {
        if (_pending < 0) return;
        setProc.command = ["brightnessctl", "-q", "set", Math.round(_pending * 100) + "%"];
        _pending = -1;
        setProc.running = true;
    }
    Process { id: setProc; onExited: sys._flush() }
    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 4) sys.brightness = parseInt(f[3]) / 100;
            }
        }
    }
    function refreshBrightness() { getProc.running = true; }
    Component.onCompleted: refreshBrightness()

    // ── helpers ──
    function run(cmd) { Quickshell.execDetached(cmd); }

    function duration(secs) {
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }
}
