// "Caffeine": when active, hypridle doesn't turn off or lock the screen.
//
// The Wayland inhibitor needs a surface, so it lives in its own
// 1×1 px window, transparent, with no clicks or reserved space, which only exists
// while active. That way it doesn't depend on the bar (Super+B destroys it).
// Like every singleton, it is created the first time something uses Idle (the bar
// button, or shell.qml so it also exists in Mac Mode) and from then on
// it lives until Quickshell restarts.
//
// Mac Mode: macshell doesn't create its own inhibitor. It toggles it with
// `qs ipc call idle toggle`, queries it with `qs ipc call idle get` and watches
// $XDG_RUNTIME_DIR/qs-idle-inhibited, which is rewritten here on every change ("1" or "0").
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    property bool inhibited: false

    // FileView writes even if it hasn't read anything (preload: false) and the path is already
    // set in onCompleted; the write is atomic (temporary file + rename) and
    // FileView also watches the folder, so macshell's keeps getting notified.
    // Without XDG_RUNTIME_DIR nothing is written (no /tmp, which is shared by everyone).
    function save() {
        if (stateFile.path !== "")
            stateFile.setText(inhibited ? "1" : "0");
    }
    onInhibitedChanged: save()
    Component.onCompleted: save()

    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/qs-idle-inhibited" : ""
        preload: false   // only written
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
