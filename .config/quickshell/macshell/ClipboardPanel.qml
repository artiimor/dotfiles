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

    // cliphist lines ("<id>\t<preview>")
    property var lines: []

    Process {
        running: true
        command: ["sh", "-c", "cliphist list | head -n 12"]
        stdout: StdioCollector {
            onStreamFinished: cp.lines = text.split("\n").filter(l => l.includes("\t"))
        }
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.margins: 6
        text: I18n.tr("Clipboard")
    }

    Repeater {
        model: cp.lines
        delegate: MenuRow {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            text: modelData.slice(modelData.indexOf("\t") + 1).replace(/\s+/g, " ").trim()
            checkable: true
            checked: index === 0
            onTriggered: {
                Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", modelData]);
                cp.done();
            }
        }
    }

    Text {
        visible: cp.lines.length === 0
        Layout.margins: 8
        text: I18n.tr("Empty")
        color: Theme.dim
        font.pointSize: 9.5
    }

    Divider { Layout.topMargin: 4; Layout.bottomMargin: 4 }

    MenuRow {
        Layout.fillWidth: true
        text: I18n.tr("Clear History")
        onTriggered: {
            Quickshell.execDetached(["cliphist", "wipe"]);
            cp.done();
        }
    }
}
