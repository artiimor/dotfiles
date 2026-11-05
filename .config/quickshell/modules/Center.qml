// Centro: reloj. Al pasar el ratón se despliegan brillo, luz nocturna y
// cafeína a su derecha (sin moverlo: el cajón cuelga por fuera del ancho del
// reloj); encima del reloj aparece el calendario.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

Item {
    id: root

    required property PanelWindow bar

    // Solo cuenta el reloj, así anchors.centerIn lo deja siempre en el centro
    implicitWidth: clockIcon.implicitWidth
    implicitHeight: Theme.barHeight

    // El cajón sigue abierto mientras el ratón esté en el reloj o en el cajón
    HoverHandler { id: hover }
    HoverHandler { id: drawerHover; parent: drawer }

    // Clic en el reloj alterna hora / fecha
    property bool showDate: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarIcon {
        id: clockIcon
        padding: 16
        pixelSize: Theme.fontSize
        color: Theme.accent
        icon: root.showDate
            ? "󰃭  " + clock.date.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            : "󰥔  " + Qt.formatTime(clock.date, "HH:mm")

        onClicked: root.showDate = !root.showDate
        onScrolledUp: calendar.shift(-1)
        onScrolledDown: calendar.shift(1)

        Tooltip {
            target: clockIcon
            show: clockIcon.hovered
            onVisibleChanged: if (!visible) calendar.reset()

            Calendar { id: calendar }
        }
    }

    Drawer {
        id: drawer
        anchors.left: clockIcon.right
        open: hover.hovered || drawerHover.hovered

        BarIcon {
            icon: ["󰃞", "󰃟", "󰃠"][Math.min(2, Math.floor(Brightness.percent / 34))]
            color: Theme.yellow
            tooltip: `Brillo ${Brightness.percent}%`
            onScrolledUp: Brightness.raise()
            onScrolledDown: Brightness.lower()
        }

        BarIcon {
            icon: NightLight.icon
            color: NightLight.state === "on" ? Theme.yellow
                 : NightLight.state === "off" ? Theme.muted
                 : Qt.alpha(Theme.muted, 0.5)
            tooltip: NightLight.tooltip
            onClicked: NightLight.toggle()
            onScrolledUp: NightLight.cooler()
            onScrolledDown: NightLight.warmer()
        }

        BarIcon {
            icon: Idle.inhibited ? "󰅶" : "󰾪"
            color: Idle.inhibited ? Theme.yellow : Theme.muted
            tooltip: Idle.inhibited ? "Sin suspensión automática" : "Suspensión automática activa"
            onClicked: Idle.inhibited = !Idle.inhibited
        }
    }

    IdleInhibitor {
        window: root.bar
        enabled: Idle.inhibited
    }
}
