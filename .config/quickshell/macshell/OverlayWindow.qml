pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Ventana a pantalla completa con una tarjeta (centrada en horizontal) que aparece con fundido y escala
// (Spotlight, menú de apagado). Los hijos van dentro de la tarjeta; su tamaño, posición
// y color se ponen desde fuera con `card.*`. Clic fuera de la tarjeta la cierra.
PanelWindow {
    id: win

    property bool open: false
    signal shown()   // tras cada show(), para que cada ventana reinicie lo suyo
    function toggle() { open ? close() : show(); }
    function show() { open = true; shown(); }
    function close() { open = false; }

    readonly property int blurRadius: 22
    property real closedScale: 0.97   // escala de la tarjeta al cerrarse
    property int fadeMs: 140
    property int scaleMs: 160
    property real dim: 0              // oscurecido del escritorio al abrir (0 = nada)

    property alias card: cardRect
    default property alias content: cardRect.data

    visible: open || cardRect.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    BackgroundEffect.blurRegion: Region { item: cardRect; radius: win.blurRadius }

    Rectangle {
        visible: win.dim > 0
        anchors.fill: parent
        color: "black"
        opacity: win.open ? win.dim : 0
        Behavior on opacity { NumberAnimation { duration: win.fadeMs } }
    }
    MouseArea { anchors.fill: parent; enabled: win.open; onClicked: win.close() }

    Rectangle {
        id: cardRect
        x: (win.width - width) / 2
        radius: win.blurRadius
        border.color: Theme.border
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : win.closedScale
        Behavior on opacity { NumberAnimation { duration: win.fadeMs } }
        Behavior on scale { NumberAnimation { duration: win.scaleMs; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // no cerrar al hacer clic dentro
    }
}
