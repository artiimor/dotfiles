// Center: clock with the date. On hover, night light,
// caffeine and increase contrast slide out to its right (without moving it: the drawer hangs
// outside the clock's width); the calendar appears below the clock.
import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Item {
    id: root

    // Only the clock counts, so anchors.centerIn always keeps it centered
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
        // e.g. "jue 19  14:32" (in Spanish even if the system is in English)
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

        // Increase contrast: Theme.contrast updates by itself when the file changes
        BarIcon {
            icon: "󰆗"
            cell: Theme.iconCell
            padding: 4
            color: Theme.contrast ? Theme.yellow : TopBar.muted
            tooltip: Theme.contrast ? I18n.tr("Increase contrast: on") : I18n.tr("Increase contrast: off")
            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/share/wasdjy/bin/wasdjy-contrast", "toggle"])
        }
    }
}
