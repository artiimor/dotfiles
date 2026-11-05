// Workspaces en modo escritorio (los gestiona config/desktopmode.lua en
// Hyprland con Super+Alt+D). Lo usan el dock y los números de la barra.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Nombres de workspace, uno por línea en el archivo
    property list<string> workspaces: []

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desktop-workspaces"
        watchChanges: true
        printErrors: false // no existe hasta que activas el modo por primera vez
        onFileChanged: reload()
        onLoaded: root.workspaces = text().split("\n").filter(l => l !== "")
        onLoadFailed: root.workspaces = []
    }
}
