// Estado: una sola isla a la derecha con lo justo (audio, red, batería).
// Al pasar el ratón se despliega hacia la izquierda el resto (como el reloj:
// el cajón cuelga por fuera, así lo fijo no se mueve): CPU, memoria,
// temperatura, bluetooth, perfil de energía y apagado.
// La campana solo aparece si hay notificaciones (Super+A abre el panel igual).
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

Item {
    id: status

    // Se abre el cajón: Bar.qml lo usa para esconder la bandeja que queda debajo
    readonly property bool drawerOpen: drawer.open

    // Solo cuenta lo fijo; el cajón sobresale hacia la izquierda
    implicitWidth: root.implicitWidth
    implicitHeight: Theme.barHeight

    // El cajón sigue abierto mientras el ratón esté en lo fijo o en el cajón
    HoverHandler { id: hover }
    HoverHandler { id: drawerHover; parent: drawer }

    // ── Cajón: lo que no hace falta ver siempre ───────────
    Drawer {
        id: drawer
        anchors.right: root.left
        fromRight: true
        open: hover.hovered || drawerHover.hovered

        // CPU · Clic: btop (misma clase que en Waybar, así las reglas de
        // ventana de Hyprland lo siguen poniendo pequeño arriba a la derecha)
        BarIcon {
            icon: "󰻠"
            padding: 10
            color: Theme.muted
            tooltip: `CPU ${SysStats.cpu}%`
            onClicked: Quickshell.execDetached(["kitty", "--class", "waybar-popup", "-o", "window_padding_width=8", "-e", "btop"])
        }

        BarIcon {
            icon: "󰍛"
            padding: 10
            color: Theme.muted
            tooltip: `${SysStats.memUsed.toFixed(1)} / ${SysStats.memTotal.toFixed(1)} GiB`
        }

        BarIcon {
            readonly property bool critical: SysStats.temp >= SysStats.tempCritical
            icon: ["󱃃", "󰔏", "󱃂"][Math.min(2, Math.floor(3 * SysStats.temp / SysStats.tempCritical))]
            padding: 10
            color: critical ? Theme.red : Theme.muted
            tooltip: `${SysStats.temp}°C`
        }

        // Bluetooth · Clic: bzmenu (con el lanzador de Quickshell como menú)
        BarIcon {
            readonly property bool on: root.adapter?.enabled ?? false

            icon: !on ? "󰂲" : root.btConnected.length > 0 ? "󰂱" : "󰂯"
            padding: 10
            color: on ? Theme.fg : Theme.muted
            tooltip: !on ? "Bluetooth apagado"
                : root.btConnected.length > 0 ? root.btConnected.map(d => d.name).join("\n")
                : "Bluetooth encendido"

            onClicked: Quickshell.execDetached(["bzmenu", "-l", "custom", "--launcher-command",
                `${Quickshell.shellDir}/scripts/dmenu-qs -p '{hint}'`])
        }

        // Perfil de energía · Clic: menú de perfiles
        BarIcon {
            readonly property int profile: PowerProfiles.profile

            icon: profile === PowerProfile.Performance ? "󰓅"
                : profile === PowerProfile.PowerSaver ? "󰾆"
                : "󰾅"
            padding: 10
            color: Theme.fg
            tooltip: `Perfil: ${PowerProfile.toString(profile)}\nClic: cambiar`

            onClicked: Launcher.toggle("profiles")
        }

        // Apagado · Clic: menú de energía (también con Super+Escape)
        BarIcon {
            icon: "⏻"
            padding: 10
            color: hovered ? Theme.red : Theme.muted
            onClicked: Launcher.toggle("power")
        }

        // Separador fino entre el cajón y lo fijo
        Item {
            implicitWidth: 9
            implicitHeight: Theme.barHeight

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: 14
                color: Theme.border
            }
        }
    }

    Island {
        id: root
        anchors.right: parent.right
        padding: 6

        // ── Audio ─────────────────────────────────────────────
        // Clic: pavucontrol · Clic derecho: silenciar · Rueda: volumen ±5%
        readonly property PwNode sink: Pipewire.defaultAudioSink
        // Sin esto Pipewire no rellena sink.audio
        PwObjectTracker { objects: [root.sink] }

        BarIcon {
            readonly property real volume: root.sink?.audio?.volume ?? 0
            readonly property bool muted: root.sink?.audio?.muted ?? false
            readonly property bool bluetooth: (root.sink?.name ?? "").startsWith("bluez")

            icon: muted ? "󰝟" : (bluetooth ? "󰂯 " : "") + ["󰕿", "󰖀", "󰕾"][Math.min(2, Math.floor(volume * 3))]
            padding: 10
            color: muted ? Theme.muted : Theme.pink
            tooltip: root.sink ? `${root.sink.description}\nVolumen ${Math.round(volume * 100)}%` : "Sin salida de audio"

            onClicked: m => {
                if (m.button === Qt.RightButton)
                    root.sink.audio.muted = !muted;
                else
                    Quickshell.execDetached(["pavucontrol"]);
            }
            onScrolledUp: root.sink.audio.volume = Math.min(1, volume + 0.05)
            onScrolledDown: root.sink.audio.volume = Math.max(0, volume - 0.05)
        }

        // ── Red ───────────────────────────────────────────────
        // Clic: networkmanager_dmenu
        BarIcon {
            icon: Net.wired ? "󰈀"
                : Net.wifi ? ["󰤟", "󰤢", "󰤥", "󰤨"][Math.min(3, Math.floor(Net.signal / 25))]
                : "󰤭"
            padding: 10
            color: Net.wired || Net.wifi ? Theme.cyan : Theme.muted
            tooltip: {
                if (!Net.wired && !Net.wifi)
                    return "Desconectado";
                const name = Net.wired ? Net.iface : `${Net.wifiNetwork?.name ?? "Wi-Fi"} (${Net.signal}%)`;
                return `${name}\n${Net.ip || "Sin IP"}\n󰇚 ${Net.speed(Net.down)}   󰕒 ${Net.speed(Net.up)}`;
            }

            onClicked: Quickshell.execDetached(["networkmanager_dmenu"])
        }

        readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
        readonly property var btConnected: adapter?.devices.values.filter(d => d.connected) ?? []

        // ── Batería ───────────────────────────────────────────
        readonly property UPowerDevice battery: UPower.displayDevice
        readonly property int percent: {
            const p = battery?.percentage ?? 0;
            return Math.round(p > 1 ? p : p * 100);
        }
        readonly property bool charging: battery?.state === UPowerDeviceState.Charging
        readonly property bool plugged: !UPower.onBattery && !charging

        function formatTime(seconds) {
            if (!seconds)
                return "";
            const h = Math.floor(seconds / 3600);
            const m = Math.floor(seconds % 3600 / 60);
            return h > 0 ? `${h} h ${m} min` : `${m} min`;
        }

        BarIcon {
            id: batteryIcon
            readonly property bool warning: !root.charging && root.percent <= 30
            readonly property bool critical: !root.charging && !root.plugged && root.percent <= 15

            icon: root.charging ? "󰂄"
                : root.plugged ? "󰚥"
                : ["󰂎", "󰁺", "󰁼", "󰁾", "󰂀", "󰂂", "󰁹"][Math.min(6, Math.floor(root.percent / 100 * 7))]
            padding: 10
            color: root.charging ? Theme.mint
                : critical ? (blink ? Theme.fg : Theme.red)
                : warning ? Theme.yellow
                : Theme.peach
            tooltip: {
                const time = root.formatTime(root.charging ? root.battery?.timeToFull : root.battery?.timeToEmpty);
                return `${root.percent}%${time ? " · " + time : ""}\n${Math.abs(root.battery?.changeRate ?? 0).toFixed(1)} W`;
            }

            // Parpadeo con batería crítica
            property bool blink: false
            Timer {
                interval: 500
                repeat: true
                running: batteryIcon.critical
                onTriggered: batteryIcon.blink = !batteryIcon.blink
                onRunningChanged: if (!running) batteryIcon.blink = false
            }
        }

        // ── Notificaciones ────────────────────────────────────
        // Clic: panel · Clic derecho: no molestar
        BarIcon {
            visible: Notifs.count > 0 || Notifs.dnd || Notifs.centerOpen
            icon: Notifs.dnd ? "󰂛" : Notifs.count > 0 ? "󱅫" : "󰂚"
            padding: 10
            color: Notifs.centerOpen || Notifs.count > 0 ? Theme.accent : Theme.muted
            tooltip: Notifs.count > 0 ? `${Notifs.count} notificaciones` : ""

            onClicked: m => m.button === Qt.RightButton ? Notifs.toggleDnd() : Notifs.togglePanel()
        }
    }
}
