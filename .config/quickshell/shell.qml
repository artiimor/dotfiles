// Entry point. `qs` loads this file (~/.config/quickshell/shell.qml)
// and reloads by itself when any .qml in this folder is saved.
//
// Structure:
//   Theme.qml     colors and sizes (the first thing to touch)
//   Bar.qml       the bar: which modules go on the left, center and right
//   modules/      each bar island (workspaces, clock, audio...)
//   components/   reusable pieces (island, icon with tooltip, drawer)
//   services/     shared data (memory, brightness, night light...)
//   scripts/      shell scripts used by the modules

import QtQuick
import Quickshell
import qs.modules
import qs.services

ShellRoot {
    id: root

    // Desktop profile (~/.local/state/desktop-profile, written by
    // ~/.config/themes/config-set; chosen with Super+Shift+T):
    //   "mac"      the top bar, notifications and Spotlight come from
    //              macshell (./macshell; started by autostart.lua / config-set)
    //   "default"  the bar and notifications from here
    // No file: "mac" if macshell is present. "mac" without macshell = "default".
    // config-set restarts qs when going from Mac Mode to normal or back: Theme.mac is the
    // start-up one (from mac to mac-light only the colors change, without restarting).
    // Read by Theme (Theme.profile, Theme.mac). Until the check finishes
    // (Theme.profileReady) the bar and notifications from here aren't created
    // (otherwise they would grab the notification server)
    readonly property bool ownBar: Theme.profileReady && !Theme.mac

    // Create the Idle singleton now (caffeine): without its own bar (Mac Mode) nothing else would
    // use it and its IPC (`qs ipc call idle toggle`, the macshell button) wouldn't exist
    readonly property bool idleInhibited: Idle.inhibited
    // Same with Battery, which is what warns about low battery
    readonly property bool batteryPresent: Battery.present

    // One bar per connected screen. When hidden (Super+B) they are removed
    // completely, and with them their menus and their reserved space
    Variants {
        model: root.ownBar && TopBar.shown ? Quickshell.screens : []

        Bar {}
    }

    // Desktop-mode dock (only on Super+Alt+D workspaces)
    Dock {}

    // Wallpaper (on every screen)
    Wallpaper {}

    // These only go on the focused screen
    LazyLoader { active: root.ownBar; NotificationPopups {} }
    LazyLoader { active: root.ownBar; NotificationCenter {} }
    Osd {}
    LauncherWindow {}
    PolkitDialog {}

    // Lock screen (on all of them, only while locked)
    LockScreen {}
}
