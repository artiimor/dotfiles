// Commands to Hyprland. Its config is Lua, so each command is an
// hl.dsp.… expression, e.g. hl.dsp.window.bring_to_top(). (Careful: no braces in this
// comment, or Quickshell stops seeing the Singleton pragma)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    // A single command goes through the Hyprland socket, without spawning processes. Several go
    // together with hyprctl --batch, which applies them in order (separately they could
    // arrive out of order)
    function dispatch(...cmds) {
        if (cmds.length === 1)
            Hyprland.dispatch(cmds[0]);
        else
            Quickshell.execDetached(["hyprctl", "--batch", cmds.map(c => "dispatch " + c).join(" ; ")]);
    }
}
