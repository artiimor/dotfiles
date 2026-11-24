pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

// Renders an app's tray (DBus) menu with our own look. Submenus open in place.
ColumnLayout {
    id: tm
    required property var item          // SystemTrayItem
    signal done()
    property var stack: []              // submenu handles
    readonly property var current: stack.length ? stack[stack.length - 1] : item.menu
    // the popup is reused when another tray icon is right-clicked: start at its top level
    onItemChanged: stack = []

    implicitWidth: 240
    spacing: 1

    QsMenuOpener { id: opener; menu: tm.current }

    Text {
        Layout.fillWidth: true
        Layout.margins: 6
        visible: tm.stack.length === 0
        text: tm.item.tooltipTitle || tm.item.title || tm.item.id
        color: Theme.dim
        font.pointSize: 8.5
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
    MenuRow {
        Layout.fillWidth: true
        visible: tm.stack.length > 0
        text: "‹  Back"
        onTriggered: tm.stack = tm.stack.slice(0, -1)
    }

    Repeater {
        model: opener.children
        delegate: Loader {
            id: entry
            required property var modelData
            Layout.fillWidth: true
            sourceComponent: modelData.isSeparator ? sep : row
            Component {
                id: sep
                Item {
                    implicitHeight: 9
                    Rectangle { anchors.centerIn: parent; width: parent.width - 12; height: 1; color: Theme.tint(0.12) }
                }
            }
            Component {
                id: row
                MenuRow {
                    text: entry.modelData.text.replace(/&(?!&)/g, "")
                    iconSource: entry.modelData.icon || ""
                    enabledItem: entry.modelData.enabled
                    checkable: entry.modelData.buttonType !== QsMenuButtonType.None
                    checked: entry.modelData.checkState === Qt.Checked
                    submenu: entry.modelData.hasChildren
                    onTriggered: {
                        if (entry.modelData.hasChildren) {
                            tm.stack = tm.stack.concat([entry.modelData]);
                        } else {
                            entry.modelData.triggered();
                            tm.done();
                        }
                    }
                }
            }
        }
    }
}
