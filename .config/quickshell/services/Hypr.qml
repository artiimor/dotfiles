// Órdenes a Hyprland. Su config es Lua, así que cada orden es una expresión
// hl.dsp.…, p. ej. hl.dsp.window.bring_to_top(). (Ojo: sin llaves en este
// comentario, o Quickshell deja de ver el pragma Singleton)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    // Una orden va por el socket de Hyprland, sin lanzar procesos. Varias van
    // juntas con hyprctl --batch, que las aplica en orden (por separado podrían
    // llegar desordenadas)
    function dispatch(...cmds) {
        if (cmds.length === 1)
            Hyprland.dispatch(cmds[0]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", cmds.map(c => "dispatch " + c).join(" ; ")]);
    }
}
