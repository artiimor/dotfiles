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
import qs.modules

ShellRoot {
    // Una barra por cada pantalla conectada
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Dock del modo escritorio (solo en workspaces con Super+Alt+D)
    Dock {}

    // Fondo de pantalla (en todas las pantallas)
    Wallpaper {}

    // Estos van solo en la pantalla con el foco
    NotificationPopups {}
    NotificationCenter {}
    Osd {}
    LauncherWindow {}
    PolkitDialog {}

    // Pantalla de bloqueo (en todas, solo mientras está bloqueado)
    LockScreen {}
}
