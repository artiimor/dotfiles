// Punto de entrada. `qs` carga este archivo (~/.config/quickshell/shell.qml)
// y recarga solo al guardar cualquier .qml de esta carpeta.
//
// Estructura:
//   Theme.qml     colores y tamaños (lo primero que tocar)
//   Bar.qml       la barra: qué módulos van a la izquierda, centro y derecha
//   modules/      cada isla de la barra (workspaces, reloj, audio...)
//   components/   piezas reutilizables (isla, icono con tooltip, cajón)
//   services/     datos compartidos (memoria, brillo, luz nocturna...)
//   scripts/      scripts de shell que usan los módulos

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules
import qs.services

ShellRoot {
    id: root

    // Perfil del escritorio (~/.local/state/desktop-profile, lo escribe
    // ~/.config/themes/config-set; se elige con Super+Shift+T):
    //   "mac"      la barra superior, las notificaciones y el Spotlight los pone
    //              macshell (config aparte; lo arranca autostart.lua / config-set)
    //   "default"  la barra y las notificaciones de aquí
    // Sin archivo: "mac" si está macshell. "mac" sin macshell = "default".
    // config-set reinicia qs al cambiar de perfil, así que basta leerlo al arrancar.
    FileView {
        id: profileFile
        printErrors: false
        path: Quickshell.env("HOME") + "/.local/state/desktop-profile"
        onLoaded: root.profileChecked = true
        onLoadFailed: root.profileChecked = true
    }
    FileView {
        id: macshell
        printErrors: false
        path: Quickshell.env("HOME") + "/.config/quickshell/macshell/shell.qml"
        onLoaded: root.macChecked = true
        onLoadFailed: root.macChecked = true
    }
    // Las comprobaciones son asíncronas: hasta que acaben no se crea la barra ni las
    // notificaciones de aquí (si no, se quedarían con el servidor de notificaciones)
    property bool profileChecked: false
    property bool macChecked: false
    readonly property string profile: profileFile.loaded ? profileFile.text().trim() : ""
    readonly property bool macBar: macshell.loaded && root.profile !== "default"
    readonly property bool ownBar: profileChecked && macChecked && !macBar

    // Una barra por cada pantalla conectada. Al ocultarla (Super+B) se quitan
    // del todo, y con ellas sus menús y su hueco reservado
    Variants {
        model: root.ownBar && TopBar.shown ? Quickshell.screens : []

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
