pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Bloquear / suspender / cerrar sesión / reiniciar / apagar, con los botones redondos de la
// ventana de inicio de sesión de macOS. Super+Esc en Hyprland (`ipc call power toggle`).
// Flechas o Tab para moverse, Intro para elegir, Esc o clic fuera para cerrar.
OverlayWindow {
    id: win

    onShown: sel = 0

    property string userName: Quickshell.env("USER") ?? ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) win.userName = text.trim() }
    }

    readonly property var actions: [
        { label: I18n.tr("Lock"), glyph: "lock", cmd: "loginctl lock-session" },
        { label: I18n.tr("Sleep"), glyph: "moon", cmd: "loginctl lock-session && sleep 0.5 && systemctl suspend" },
        { label: I18n.tr("Log Out"), glyph: "logout", cmd:
            "if uwsm check is-active; then uwsm stop; else loginctl terminate-session \"$XDG_SESSION_ID\"; fi" },
        { label: I18n.tr("Restart"), glyph: "restart", cmd: "systemctl reboot" },
        { label: I18n.tr("Shut Down"), glyph: "power", cmd: "systemctl poweroff" }
    ]
    property int sel: 0

    function run(i) {
        close();
        Quickshell.execDetached(["sh", "-c", actions[i].cmd]);
    }

    WlrLayershell.namespace: "macshell-power"
    dim: 0.35
    fadeMs: 180
    scaleMs: 220
    closedScale: 0.94

    card.y: (height - card.height) / 2
    card.width: buttons.implicitWidth + 64
    card.height: col.implicitHeight + 48
    card.color: Theme.card

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 22
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
                        border.width: btn.current ? 2 : Theme.outlineWidth
                        border.color: btn.current ? Theme.accent : Theme.separator
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
