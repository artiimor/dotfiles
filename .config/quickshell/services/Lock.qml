// Lock screen: replaces hyprlock. The logic lives here (locking,
// checking the password with PAM); the look is in modules/LockSurface.qml.
//
// Locked with `qs ipc call lock lock` (hypridle does it when running
// `loginctl lock-session`, which is what Super+Ctrl+L and the power menu use).
// On purpose there is NO way to unlock from outside: only with the password.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs

Singleton {
    id: root

    property bool locked: false

    // What is typed in the password field (shared between screens)
    property string password: ""
    property bool checking: false
    property bool failed: false
    property int attempts: 0
    property string error: ""
    property bool capsLock: false

    function lock() {
        password = "";
        failed = false;
        attempts = 0;
        locked = true;
    }

    function submit() {
        if (checking || password === "")
            return;
        checking = true;
        failed = false;
        pam.start();
    }

    // PAM with the same configuration hyprlock used (/etc/pam.d/login)
    PamContext {
        id: pam
        config: "login"

        // PAM asks for the password: we give it
        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }

        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.locked = false;
                root.attempts = 0;
            } else {
                root.attempts++;
                root.failed = true;
                root.error = result === PamResult.MaxTries ? I18n.tr("Too many attempts") : I18n.tr("Wrong password");
            }
            root.password = "";
        }

        onError: err => {
            root.checking = false;
            root.failed = true;
            root.error = I18n.tr("PAM error: %1", PamError.toString(err));
            root.password = "";
        }
    }

    // Caps Lock: Qt doesn't know it, Hyprland is asked on key presses
    function checkCapsLock() { caps.running = true; }
    Process {
        id: caps
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.capsLock = JSON.parse(text).keyboards.some(k => k.main && k.capsLock);
                } catch (e) {}
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
    }
}
