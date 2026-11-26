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

    // Acciones en cola: con la rueda llegan pasos mientras el script aún corre,
    // y lanzarlo otra vez se ignoraría. Se aplican en orden y luego se lee el estado
    property var queue: []

    function run(action) {
        queue.push(action);
        if (!action_.running)
            next();
    }

    function next() {
        const action = queue.shift();
        if (action)
            action_.exec([script, action]);
        else
            status.running = true;
    }

    Process {
        id: action_
        onExited: root.next()
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
