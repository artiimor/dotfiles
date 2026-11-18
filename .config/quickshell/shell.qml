// Punto de entrada. `qs` carga este archivo (~/.config/quickshell/shell.qml)
// y recarga solo al guardar cualquier .qml de esta carpeta.
//
// Estructura:
//   Theme.qml     colores y tamaños (lo primero que tocar)
//   Bar.qml       la barra: qué módulos van a la izquierda, centro y derecha
//   modules/      cada isla de la barra (workspaces, reloj, audio...)
//   components/   piezas reutilizables (isla, icono con tooltip, cajón)
//   services/     datos compartidos (CPU, brillo, luz nocturna...)
//   scripts/      scripts de shell que usan los módulos

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules

ShellRoot {
    id: root

    // Si está instalada la barra estilo macOS (macshell, repo plasma-mac), ella
    // pone la barra superior, las notificaciones y el Spotlight (la arranca
    // autostart.lua). Para volver a la barra de aquí, borra/renombra esa carpeta.
    FileView {
        id: macshell
        printErrors: false
        path: Quickshell.env("HOME") + "/.config/quickshell/macshell/shell.qml"
        onLoaded: root.macChecked = true
        onLoadFailed: root.macChecked = true
    }
    // La comprobación es asíncrona: hasta que acabe no se crea la barra ni las
    // notificaciones de aquí (si no, se quedarían con el servidor de notificaciones)
    property bool macChecked: false
    readonly property bool macBar: macshell.loaded
    readonly property bool ownBar: macChecked && !macBar

    // Una barra por cada pantalla conectada
    Variants {
        model: root.ownBar ? Quickshell.screens : []

        Bar {}
    }

    // Dock del modo escritorio (solo en workspaces con Super+Alt+D)
    Dock {}

    // Fondo de pantalla (en todas las pantallas)
    Wallpaper {}

    // Estos van solo en la pantalla con el foco
    LazyLoader { active: root.ownBar; NotificationPopups {} }
    LazyLoader { active: root.ownBar; NotificationCenter {} }
    Osd {}
    LauncherWindow {}
    PolkitDialog {}

    // Pantalla de bloqueo (en todas, solo mientras está bloqueado)
    LockScreen {}
}
