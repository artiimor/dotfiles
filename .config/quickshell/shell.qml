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
import qs.modules
import qs.services

ShellRoot {
    id: root

    // Perfil del escritorio (~/.local/state/desktop-profile, lo escribe
    // ~/.config/themes/config-set; se elige con Super+Shift+T):
    //   "mac"      la barra superior, las notificaciones y el Spotlight los pone
    //              macshell (./macshell; lo arranca autostart.lua / config-set)
    //   "default"  la barra y las notificaciones de aquí
    // Sin archivo: "mac" si está macshell. "mac" sin macshell = "default".
    // config-set reinicia qs al cambiar de perfil, así que basta leerlo al arrancar.
    // Lo lee Theme (Theme.profile, Theme.mac). Hasta que acabe la comprobación
    // (Theme.profileReady) no se crea la barra ni las notificaciones de aquí
    // (si no, se quedarían con el servidor de notificaciones)
    readonly property bool ownBar: Theme.profileReady && !Theme.mac

    // Crea ya el singleton Idle (cafeína): sin barra propia (Modo Mac) nadie más lo
    // usaría y su IPC (`qs ipc call idle toggle`, el botón de macshell) no existiría
    readonly property bool idleInhibited: Idle.inhibited

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
