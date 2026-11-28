// Luz nocturna. Toda la lógica está en scripts/nightlight.sh (habla con
// hyprsunset); esto lo ejecuta, guarda lo que devuelve y pone los textos.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/nightlight.sh"

    // Lo que devuelve el script: class ("on" | "off" | "unavailable"), temperature
    // y next (epoch del próximo cambio del horario de hyprsunset.conf)
    property string state: "unavailable"
    property int temperature
    property real nextChange: 0   // ms; hasta entonces no hace falta volver a leer

    readonly property string icon: state === "on" ? "󰖔" : "󰖙"
    readonly property string tooltip: state === "on" ? I18n.tr("Night light: %1 K", temperature) + "\n" + I18n.tr("Scroll: adjust · Click: turn off")
        : state === "off" ? I18n.tr("Night light off") + "\n" + I18n.tr("Click: turn on")
        : I18n.tr("hyprsunset is not running")

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
                    root.state = j["class"];
                    root.temperature = j.temperature;
                    // Sin hyprsunset se reintenta cada 5 min, por si arranca luego
                    root.nextChange = j["class"] === "unavailable" ? Date.now() + 300000 : j.next * 1000 + 2000;
                } catch (e) {}
            }
        }
    }

    // Solo se relee al llegar el próximo cambio del horario (y tras cada acción).
    // Se compara con la hora real en vez de un Timer con esa espera: el reloj de
    // los Timer se para al suspender, y así al reanudar se ve enseguida
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Date.now() >= root.nextChange && !status.running) status.running = true
    }
}
