pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

// Draws an app's tray menu (DBus) with our look. Submenus open in place.
ColumnLayout {
    id: tm
    required property var item          // SystemTrayItem
    signal done()
    property var stack: []              // open submenus
    readonly property var current: stack.length ? stack[stack.length - 1] : item.menu
    // the popup is reused when right-clicking another icon: start at its top level
    onItemChanged: stack = []

    implicitWidth: 240
    spacing: 1

    QsMenuOpener { id: opener; menu: tm.current }

    SectionLabel {
        Layout.fillWidth: true
        Layout.margins: 6
        visible: tm.stack.length === 0
        text: tm.item.tooltipTitle || tm.item.title || tm.item.id
    }
    MenuRow {
        Layout.fillWidth: true
        visible: tm.stack.length > 0
        text: I18n.tr("‹  Back")
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
                    Divider { anchors.centerIn: parent; width: parent.width - 12 }
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
