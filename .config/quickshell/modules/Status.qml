// Estado: una sola isla a la derecha con lo de siempre a la vista (audio,
// brillo, red, bluetooth, batería; brillo y batería solo si el equipo los
// tiene, así en un sobremesa no salen). Al pasar el ratón se despliega hacia la
// izquierda el resto (como el reloj: el cajón cuelga por fuera, así lo fijo
// no se mueve): memoria, temperatura, perfil de energía y apagado.
// La campana solo aparece si hay notificaciones (Super+A abre el panel igual).
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

Item {
    id: status

    // Se abre el cajón: Bar.qml lo usa para esconder la bandeja que queda debajo
    readonly property bool drawerOpen: drawer.open

    // Solo cuenta lo fijo; el cajón sobresale hacia la izquierda
    implicitWidth: fixed.implicitWidth
    implicitHeight: Theme.barHeight

    // ── Cajón: lo que no hace falta ver siempre ───────────
    Drawer {
        id: drawer
        anchors.right: fixed.left
        fromRight: true

        BarIcon {
            cell: Theme.iconCell
            padding: 4
            icon: "󰍛"
            color: TopBar.muted
            clickable: false
            tooltip: `${SysStats.memUsed.toFixed(1)} / ${SysStats.memTotal.toFixed(1)} GiB`
        }

        BarIcon {
            cell: Theme.iconCell
            padding: 4
            readonly property bool critical: SysStats.temp >= SysStats.tempCritical
            icon: ["󱃃", "󰔏", "󱃂"][Math.min(2, Math.floor(3 * SysStats.temp / SysStats.tempCritical))]
            color: critical ? Theme.red : TopBar.muted
            clickable: false
            tooltip: `${SysStats.temp}°C`
        }

        // Perfil de energía · Clic: menú de perfiles
        BarIcon {
            cell: Theme.iconCell
            padding: 4
            readonly property int profile: PowerProfiles.profile

            icon: profile === PowerProfile.Performance ? "󰓅"
                : profile === PowerProfile.PowerSaver ? "󰾆"
                : "󰾅"
            color: TopBar.fg
            tooltip: I18n.tr("Profile: %1\nClick: change", profile === PowerProfile.Performance ? I18n.tr("Performance")
                : profile === PowerProfile.PowerSaver ? I18n.tr("Power saver")
                : I18n.tr("Balanced"))

            onClicked: Launcher.toggle("profiles")
        }

        // Apagado · Clic: menú de energía (también con Super+Escape)
        BarIcon {
            cell: Theme.iconCell
            padding: 4
            icon: "⏻"
            color: TopBar.muted
            hoverColor: Theme.red
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
                color: TopBar.border
            }
        }
    }

    Island {
        id: fixed
        anchors.right: parent.right

        // ── Audio ─────────────────────────────────────────────
        // Clic: mezclador · Clic derecho: silenciar · Rueda: volumen ±5%
        BarIcon {
            id: volumeIcon
            cell: Theme.iconCell
            padding: 4
            icon: (Audio.bluetooth && !Audio.muted ? "󰂯 " : "") + Audio.icon
            color: Audio.muted ? TopBar.muted : TopBar.fg
            tooltip: mixer.visible ? ""
                : Audio.sink ? `${Audio.sink.description}\n` + I18n.tr("Volume %1%", Math.round(Audio.volume * 100))
                : I18n.tr("No audio output")

            onClicked: m => m.button === Qt.RightButton ? Audio.toggleMute() : mixer.toggle()
            onScrolledUp: Audio.step(0.05)
            onScrolledDown: Audio.step(-0.05)

            VolumeMixer {
                id: mixer
                target: volumeIcon
            }
        }

        // ── Brillo ────────────────────────────────────────────
        // Rueda: brillo ±5% · Solo con panel retroiluminado (portátil)
        BarIcon {
            cell: Theme.iconCell
            padding: 4
            visible: Brightness.available
            icon: Brightness.icon
            color: Theme.yellow
            clickable: false
            tooltip: I18n.tr("Brightness %1%\nWheel: adjust", Brightness.percent)
            onScrolledUp: Brightness.raise()
            onScrolledDown: Brightness.lower()
        }

        // ── Red ───────────────────────────────────────────────
        // Clic: networkmanager_dmenu
        BarIcon {
            cell: Theme.iconCell
            padding: 4
            icon: Net.wired ? "󰈀"
                : Net.wifi ? ["󰤟", "󰤢", "󰤥", "󰤨"][Math.min(3, Math.floor(Net.signal / 25))]
                : "󰤭"
            color: Net.wired || Net.wifi ? TopBar.fg : TopBar.muted
            tooltip: {
                if (!Net.wired && !Net.wifi)
                    return I18n.tr("Disconnected");
                const name = Net.wired ? Net.iface : `${Net.wifiNetwork?.name ?? "Wi-Fi"} (${Net.signal}%)`;
                return `${name}\n${Net.ip || I18n.tr("No IP")}\n󰇚 ${Net.speed(Net.down)}   󰕒 ${Net.speed(Net.up)}`;
            }

            onClicked: Quickshell.execDetached(["networkmanager_dmenu"])
        }

        // ── Bluetooth ─────────────────────────────────────────
        // Clic: bzmenu (con el lanzador de Quickshell como menú)
        readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
        readonly property var btConnected: adapter?.devices.values.filter(d => d.connected) ?? []

        BarIcon {
            cell: Theme.iconCell
            padding: 4
            readonly property bool on: fixed.adapter?.enabled ?? false

            icon: !on ? "󰂲" : fixed.btConnected.length > 0 ? "󰂱" : "󰂯"
            color: on ? TopBar.fg : TopBar.muted
            tooltip: !on ? I18n.tr("Bluetooth off")
                : fixed.btConnected.length > 0 ? fixed.btConnected.map(d => d.name).join("\n")
                : I18n.tr("Bluetooth on")

            onClicked: Quickshell.execDetached(["bzmenu", "-l", "custom", "--launcher-command",
                `${Quickshell.shellDir}/scripts/dmenu-qs -p '{hint}'`])
        }

        // ── Batería ───────────────────────────────────────────
        // Solo si UPower ve una batería de portátil (en un sobremesa no hay)
        function formatTime(seconds) {
            if (!seconds)
                return "";
            const h = Math.floor(seconds / 3600);
            const m = Math.floor(seconds % 3600 / 60);
            return h > 0 ? `${h} h ${m} min` : `${m} min`;
        }

        BarIcon {
            id: batteryIcon
            cell: Theme.iconCell
            padding: 4
            visible: Battery.present
            readonly property bool warning: !Battery.charging && Battery.percent <= 30
            readonly property bool critical: !Battery.charging && !Battery.plugged && Battery.percent <= 15

            icon: Battery.charging ? "󰂄"
                : Battery.plugged ? "󰚥"
                : ["󰂎", "󰁺", "󰁼", "󰁾", "󰂀", "󰂂", "󰁹"][Math.min(6, Math.floor(Battery.percent / 100 * 7))]
            color: Battery.charging ? TopBar.fg
                : critical ? (blink ? TopBar.fg : Theme.red)
                : warning ? Theme.yellow
                : TopBar.fg
            tooltip: {
                const time = fixed.formatTime(Battery.charging ? Battery.device?.timeToFull : Battery.device?.timeToEmpty);
                return `${Battery.percent}%${time ? " · " + time : ""}\n${Math.abs(Battery.device?.changeRate ?? 0).toFixed(1)} W`;
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
            cell: Theme.iconCell
            padding: 4
            visible: Notifs.count > 0 || Notifs.dnd || Notifs.centerOpen
            icon: Notifs.dnd ? "󰂛" : Notifs.count > 0 ? "󱅫" : "󰂚"
            color: Notifs.centerOpen || Notifs.count > 0 ? TopBar.accent : TopBar.muted
            tooltip: Notifs.count > 0 ? I18n.tr("%1 notifications", Notifs.count) : ""

            onClicked: m => m.button === Qt.RightButton ? Notifs.toggleDnd() : Notifs.togglePanel()
        }
    }
}
