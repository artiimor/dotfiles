// "Cafeína": si está activo, hypridle no apaga ni bloquea la pantalla.
//
// El inhibidor de Wayland necesita una superficie, así que va en una ventana
// propia de 1×1 px, transparente, sin clics ni hueco reservado, que solo existe
// mientras está activo. Así no depende de la barra (Super+B la destruye).
// Como todo singleton, se crea la primera vez que alguien usa Idle (el botón
// de la barra) y a partir de ahí vive hasta que se reinicia Quickshell.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    property bool inhibited: false

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
