pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Fullscreen window with a card (horizontally centered) that appears with a fade and scale
// (Spotlight, power menu). Children go inside the card; its size, position
// and color are set from outside with `card.*`. Clicking outside the card closes it.
PanelWindow {
    id: win

    property bool open: false
    signal shown()   // after every show(), so each window resets its own state
    function toggle() { open ? close() : show(); }
    function show() { open = true; shown(); }
    function close() { open = false; }

    readonly property int blurRadius: 22
    property real closedScale: 0.97   // card scale when closing
    property int fadeMs: 140
    property int scaleMs: 160
    property real dim: 0              // desktop dimming on open (0 = none)

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

        MouseArea { anchors.fill: parent }   // don't close when clicking inside
    }
}
