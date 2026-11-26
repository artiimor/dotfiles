// Mostrar u ocultar la barra de arriba (Super+B), como en Omarchy. Oculta, deja
// libre su hueco y las ventanas usan toda la altura. No se guarda al reiniciar.
//
// Desde fuera:
//   qs ipc call bar toggle
//
// En el Modo Mac la barra es la de macshell: aquí no hace nada.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool shown: true
    // Margen de arriba de lo que sale debajo de la barra (lanzador, notificaciones)
    readonly property int belowBar: shown ? Theme.barHeight + Theme.gap * 2 : Theme.gap

    IpcHandler {
        target: "bar"
        function toggle(): void {
            if (!Theme.mac)
                root.shown = !root.shown;
        }
    }
}
