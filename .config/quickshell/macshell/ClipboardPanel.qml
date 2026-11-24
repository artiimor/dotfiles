pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Clipboard history (cliphist).
ColumnLayout {
    id: cp
    signal done()
    implicitWidth: 300
    spacing: 1

    property var entries: []
    // cliphist lines ("<id>\t<preview>")
    property var lines: []

    Process {
        running: true
        command: ["sh", "-c", "cliphist list | head -n 12"]
        stdout: StdioCollector {
            onStreamFinished: {
                cp.lines = text.split("\n").filter(l => l.includes("\t"));
                cp.entries = cp.lines.map(l => l.slice(l.indexOf("\t") + 1));
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 6
        text: "Clipboard"
        color: Theme.dim
        font.pointSize: 8.5
        font.weight: Font.DemiBold
    }

    Repeater {
        model: cp.entries
        delegate: MenuRow {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            text: modelData.replace(/\s+/g, " ").trim()
            checkable: true
            checked: index === 0
            onTriggered: {
                Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", cp.lines[index]]);
                cp.done();
            }
        }
    }

    Text {
        visible: cp.entries.length === 0
        Layout.margins: 8
        text: "Empty"
        color: Theme.dim
        font.pointSize: 9.5
    }

    Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4; implicitHeight: 1; color: Theme.tint(0.1) }

    MenuRow {
        Layout.fillWidth: true
        text: "Clear History"
        onTriggered: {
            Quickshell.execDetached(["cliphist", "wipe"]);
            cp.done();
        }
    }
}
