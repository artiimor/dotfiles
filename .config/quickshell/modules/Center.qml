// Centro: reloj con la fecha. Al pasar el ratón se despliegan luz nocturna y
// cafeína a su derecha (sin moverlo: el cajón cuelga por fuera del ancho del
// reloj); debajo del reloj aparece el calendario.
import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Item {
    id: root

    // Solo cuenta el reloj, así anchors.centerIn lo deja siempre en el centro
    implicitWidth: clockIcon.implicitWidth
    implicitHeight: Theme.barHeight

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
        icon: "󰥔  " + clock.date.toLocaleString(Qt.locale(), "ddd d  HH:mm")

        onScrolledUp: calendar.shift(-1)
        onScrolledDown: calendar.shift(1)

        Tooltip {
            target: clockIcon
            show: clockIcon.hovered
            onVisibleChanged: if (!visible) calendar.reset()

            Calendar {
                id: calendar
                today: clock.date
            }
        }
    }

    Drawer {
        id: drawer
        anchors.left: clockIcon.right

        BarIcon {
            icon: NightLight.icon
            padding: 14
            color: NightLight.state === "on" ? Theme.yellow
                 : NightLight.state === "off" ? Theme.muted
                 : Theme.withAlpha(Theme.muted, 0.5)
            tooltip: NightLight.tooltip
            onClicked: NightLight.toggle()
            onScrolledUp: NightLight.cooler()
            onScrolledDown: NightLight.warmer()
        }

        BarIcon {
            icon: Idle.inhibited ? "󰅶" : "󰾪"
            padding: 14
            color: Idle.inhibited ? Theme.yellow : Theme.muted
            tooltip: Idle.inhibited ? I18n.tr("Automatic suspend off") : I18n.tr("Automatic suspend on")
            onClicked: Idle.inhibited = !Idle.inhibited
        }
    }
}
