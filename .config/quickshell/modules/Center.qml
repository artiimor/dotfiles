// Centro: reloj con la fecha. Al pasar el ratón se despliegan luz nocturna,
// cafeína y aumentar contraste a su derecha (sin moverlo: el cajón cuelga por
// fuera del ancho del reloj); debajo del reloj aparece el calendario.
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
        color: TopBar.accent
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
            cell: Theme.iconCell
            padding: 4
            color: NightLight.state === "on" ? Theme.yellow
                 : NightLight.state === "off" ? TopBar.muted
                 : Theme.withAlpha(TopBar.muted, 0.5)
            tooltip: NightLight.tooltip
            onClicked: NightLight.toggle()
            onScrolledUp: NightLight.cooler()
            onScrolledDown: NightLight.warmer()
        }

        BarIcon {
            icon: Idle.inhibited ? "󰅶" : "󰾪"
            cell: Theme.iconCell
            padding: 4
            color: Idle.inhibited ? Theme.yellow : TopBar.muted
            tooltip: Idle.inhibited ? I18n.tr("Automatic suspend off") : I18n.tr("Automatic suspend on")
            onClicked: Idle.inhibited = !Idle.inhibited
        }

        // Aumentar contraste: Theme.contrast se actualiza solo al cambiar el archivo
        BarIcon {
            icon: "󰆗"
            cell: Theme.iconCell
            padding: 4
            color: Theme.contrast ? Theme.yellow : TopBar.muted
            tooltip: Theme.contrast ? I18n.tr("Increase contrast: on") : I18n.tr("Increase contrast: off")
            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/themes/contrast-set", "toggle"])
        }
    }
}
