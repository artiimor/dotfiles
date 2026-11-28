// Workspaces in desktop mode (managed by config/desktopmode.lua in
// Hyprland: in the mac profiles all numbered ones, in default the Super+Alt+D ones). Used by the dock and the bar numbers.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Workspace names, one per line in the file
    property list<string> workspaces: []

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desktop-workspaces"
        watchChanges: true
        printErrors: false // doesn't exist until you enable the mode for the first time
        onFileChanged: reload()
        onLoaded: root.workspaces = text().split("\n").filter(l => l !== "")
        onLoadFailed: root.workspaces = []
    }
}
