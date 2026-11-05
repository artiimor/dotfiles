// Luz nocturna. Toda la lógica está en scripts/nightlight.sh (habla con
// hyprsunset); esto solo lo ejecuta y guarda lo que devuelve.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/nightlight.sh"

    // Lo que devuelve el script: { text, class: "on" | "off" | "unavailable", tooltip }
    property string icon: "󰖙"
    property string state: "unavailable"
    property string tooltip

    function toggle() { run("toggle"); }
    function warmer() { run("down"); }
    function cooler() { run("up"); }

    function run(action) {
        action_.command = [script, action];
        action_.running = true;
    }

    Process {
        id: action_
        onExited: status.running = true
    }

    Process {
        id: status
        command: [root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.icon = j.text;
                    root.state = j["class"];
                    root.tooltip = j.tooltip;
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: status.running = true
    }
}
