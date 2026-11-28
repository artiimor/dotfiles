// Night light. All the logic is in scripts/nightlight.sh (talks to
// hyprsunset); this runs it, stores what it returns and sets the texts.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/nightlight.sh"

    // What the script returns: class ("on" | "off" | "unavailable"), temperature
    // and next (epoch of the next schedule change in hyprsunset.conf)
    property string state: "unavailable"
    property int temperature
    property real nextChange: 0   // ms; until then there's no need to read again

    readonly property string icon: state === "on" ? "󰖔" : "󰖙"
    readonly property string tooltip: state === "on" ? I18n.tr("Night light: %1 K", temperature) + "\n" + I18n.tr("Scroll: adjust · Click: turn off")
        : state === "off" ? I18n.tr("Night light off") + "\n" + I18n.tr("Click: turn on")
        : I18n.tr("hyprsunset is not running")

    function toggle() { run("toggle"); }
    function warmer() { run("down"); }
    function cooler() { run("up"); }

    // Queued actions: with the wheel, steps arrive while the script is still running,
    // and launching it again would be ignored. They are applied in order and then the state is read
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
                    // Without hyprsunset it retries every 5 min, in case it starts later
                    root.nextChange = j["class"] === "unavailable" ? Date.now() + 300000 : j.next * 1000 + 2000;
                } catch (e) {}
            }
        }
    }

    // Only re-read when the next schedule change arrives (and after each action).
    // Compared against the real time instead of a Timer with that delay: the
    // Timer clock stops on suspend, and this way it is seen right after resuming
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Date.now() >= root.nextChange && !status.running) status.running = true
    }
}
