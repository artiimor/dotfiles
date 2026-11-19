// Centro: reloj con la fecha. Al pasar el ratón se despliegan luz nocturna y
// cafeína a su derecha (sin moverlo: el cajón cuelga por fuera del ancho del
// reloj); debajo del reloj aparece el calendario.
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

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarIcon {
        id: clockIcon
        padding: 16
        pixelSize: Theme.fontSize
        color: Theme.accent
        clickable: false
        // p. ej. "jue 19  14:32" (en español aunque el sistema esté en inglés)
        icon: "󰥔  " + clock.date.toLocaleString(Qt.locale("es_ES"), "ddd d  HH:mm")

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
