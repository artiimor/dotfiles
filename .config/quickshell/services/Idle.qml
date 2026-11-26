// "Cafeína": si está activo, hypridle no apaga ni bloquea la pantalla.
//
// El inhibidor de Wayland necesita una superficie, así que va en una ventana
// propia de 1×1 px, transparente, sin clics ni hueco reservado, que solo existe
// mientras está activo. Así no depende de la barra (Super+B la destruye).
// Como todo singleton, se crea la primera vez que alguien usa Idle (el botón
// de la barra, o shell.qml para que exista también en el Modo Mac) y a partir
// de ahí vive hasta que se reinicia Quickshell.
//
// Modo Mac: macshell no crea su propio inhibidor. Lo cambia con
// `qs ipc call idle toggle` y lee el estado de $XDG_RUNTIME_DIR/qs-idle-inhibited,
// que se reescribe aquí en cada cambio ("1" o "0").
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    property bool inhibited: false

    onInhibitedChanged: stateFile.setText(inhibited ? "1" : "0")
    Component.onCompleted: stateFile.setText(inhibited ? "1" : "0")

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-idle-inhibited"
        // sin renombrar: así el FileView de macshell que lo vigila no lo pierde
        atomicWrites: false
        preload: false   // solo se escribe
        printErrors: false
    }

    IpcHandler {
        target: "idle"
        function toggle(): void { root.inhibited = !root.inhibited; }
        function get(): bool { return root.inhibited; }
    }

    PanelWindow {
        id: win
        visible: root.inhibited
        anchors.top: true
        anchors.left: true
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "qs-idle"

        IdleInhibitor {
            window: win
            enabled: true
        }
    }
}
