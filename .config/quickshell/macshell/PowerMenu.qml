pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Lock / sleep / log out / restart / shut down, with the round buttons of the
// macOS login window. Super+Esc on Hyprland (`ipc call power toggle`).
// Arrows or Tab to move, Enter to choose, Esc or click outside to close.
PanelWindow {
    id: win

    property bool open: false
    function toggle() { open ? close() : show(); }
    function show() { sel = 0; open = true; }
    function close() { open = false; }

    property string userName: Quickshell.env("USER") ?? ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) win.userName = text.trim() }
    }

    readonly property var actions: [
        { label: "Lock", glyph: "lock", cmd: "loginctl lock-session" },
        { label: "Sleep", glyph: "moon", cmd: "loginctl lock-session && sleep 0.5 && systemctl suspend" },
        { label: "Log Out", glyph: "logout", cmd:
            "if uwsm check is-active; then uwsm stop; else loginctl terminate-session \"$XDG_SESSION_ID\"; fi" },
        { label: "Restart", glyph: "restart", cmd: "systemctl reboot" },
        { label: "Shut Down", glyph: "power", cmd: "systemctl poweroff" }
    ]
    property int sel: 0

    function run(i) {
        close();
        Quickshell.execDetached(["sh", "-c", actions[i].cmd]);
    }

    visible: open || card.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "macshell-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    BackgroundEffect.blurRegion: Region { item: card; radius: 22 }

    // dim the desktop
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.open ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
    MouseArea { anchors.fill: parent; onClicked: win.close() }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: buttons.implicitWidth + 64
        height: col.implicitHeight + 48
        radius: 22
        color: Theme.card
        border.color: Theme.border
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // clicks on the card don't close it

        focus: win.open
        Keys.onPressed: e => {
            const n = win.actions.length;
            if (e.key === Qt.Key_Escape) win.close();
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab || e.key === Qt.Key_Down) win.sel = (win.sel + 1) % n;
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab || e.key === Qt.Key_Up) win.sel = (win.sel - 1 + n) % n;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) win.run(win.sel);
            else return;
            e.accepted = true;
        }

        Column {
            id: col
            anchors.centerIn: parent
            spacing: 22

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: win.userName
                color: Theme.text
                font.pointSize: 13
                font.weight: Font.DemiBold
            }

            Row {
                id: buttons
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 26

                Repeater {
                    model: win.actions
                    delegate: Item {
                        id: btn
                        required property var modelData
                        required property int index
                        readonly property bool current: win.sel === index
                        width: 64
                        height: circle.height + 10 + label.implicitHeight

                        Rectangle {
                            id: circle
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 56; height: 56; radius: 28
                            color: btn.current ? Theme.tint(0.28) : Theme.button
                            border.width: btn.current ? 2 : 0
                            border.color: Theme.accent
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Glyph {
                                anchors.centerIn: parent
                                width: 24; height: 24
                                name: btn.modelData.glyph
                            }
                        }
                        Text {
                            id: label
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: circle.bottom
                            anchors.topMargin: 10
                            text: btn.modelData.label
                            color: Theme.text
                            opacity: btn.current ? 1 : 0.75
                            font.pointSize: 9.5
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: win.sel = btn.index
                            onClicked: win.run(btn.index)
                        }
                    }
                }
            }
        }
    }
}
