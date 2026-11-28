// Window that drops down below a bar element (tray
// menu, volume mixer...). Closed with close(), Escape or clicking outside.
// The size is set by the user (implicitWidth / implicitHeight).
//
//   BarPopup {
//       id: popup
//       target: icon
//       implicitWidth: 200; implicitHeight: 100
//       Text { ... }
//   }
//   // on the icon: onClicked: popup.toggle()
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

PopupWindow {
    id: root

    required property Item target
    default property alias content: box.data

    ReopenGuard { id: guard }
    function open() {
        if (guard.canOpen())
            visible = true;
    }
    function close() {
        visible = false;
        guard.closed();
    }
    function toggle() {
        visible ? close() : open();
    }

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + Theme.popupGap
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    color: "transparent"

    // Click outside = close. It also gives the keyboard to the popup (for Escape).
    // With `visible` it never activates: a PopupWindow's window is created when shown,
    // and the grab would be requested without it. PanelWindows (launcher, notification panel)
    // already have it created even when hidden, so `visible` works for them.
    HyprlandFocusGrab {
        windows: [root]
        active: root.backingWindowVisible
        onCleared: root.close()
    }

    PopupBox {
        id: box
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }
}
