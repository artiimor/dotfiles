// Pantalla de bloqueo: sustituye a hyprlock. Aquí está la lógica (bloquear,
// comprobar la contraseña con PAM); el aspecto está en modules/LockSurface.qml.
//
// Se bloquea con `qs ipc call lock lock` (lo hace hypridle al ejecutar
// `loginctl lock-session`, que es lo que usan Super+Alt+L y el menú de energía).
// A propósito NO hay forma de desbloquear desde fuera: solo con la contraseña.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Singleton {
    id: root

    property bool locked: false

    // Lo que hay escrito en el campo de contraseña (compartido entre pantallas)
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

    // PAM con la misma configuración que usaba hyprlock (/etc/pam.d/login)
    PamContext {
        id: pam
        config: "login"

        // PAM pide la contraseña: se la damos
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
                root.error = result === PamResult.MaxTries ? "Demasiados intentos" : "Contraseña incorrecta";
            }
            root.password = "";
        }

        onError: err => {
            root.checking = false;
            root.failed = true;
            root.error = "Error de PAM: " + PamError.toString(err);
            root.password = "";
        }
    }

    // Bloq Mayús: Qt no lo sabe, se pregunta a Hyprland al pulsar teclas
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
