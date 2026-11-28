// Tray right-click menu, in the bar's style.
// Submenus open inside the same menu (with "Back" to return).
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

BarPopup {
    id: root

    property var rootMenu: null     // SystemTrayItem.menu

    // Stack of open submenus; the last one is the visible one
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : rootMenu
    onVisibleChanged: if (visible) stack = []

    implicitWidth: Math.max(180, column.implicitWidth + 12)
    implicitHeight: column.implicitHeight + 12

    // Only loads the menu (over DBus) while it is open
    QsMenuOpener {
        id: opener
        menu: root.visible ? root.current : null
    }

    Column {
        id: column
        x: 6
        y: 6
        width: parent.width - 12

        // "Back" when you are in a submenu
        MenuRow {
            visible: root.stack.length > 0
            label: I18n.tr("Back")
            leading: "󰁍"
            onActivated: root.stack = root.stack.slice(0, -1)
        }

        Repeater {
            model: opener.children

            // Each entry is a row or a separator, depending on what it is
            Column {
                id: entry
                required property QsMenuEntry modelData
                width: column.width

                Item {
                    visible: entry.modelData.isSeparator
                    width: parent.width
                    implicitHeight: 9
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        color: Theme.border
                    }
                }

                MenuRow {
                    readonly property QsMenuEntry e: entry.modelData
                    visible: !e.isSeparator
                    label: e.text.replace(/_(?!_)/g, "") // strips the "_" of keyboard shortcuts
                    enabled: e.enabled
                    icon: e.icon
                    leading: e.buttonType === QsMenuButtonType.None ? ""
                        : e.checkState === Qt.Checked ? (e.buttonType === QsMenuButtonType.RadioButton ? "󰐾" : "󰄵")
                        : (e.buttonType === QsMenuButtonType.RadioButton ? "󰄯" : "󰄱")
                    trailing: e.hasChildren ? "󰅂" : ""
                    onActivated: {
                        if (e.hasChildren) {
                            root.stack = [...root.stack, e];
                        } else {
                            e.triggered();
                            root.close();
                        }
                    }
                }
            }
        }
    }

    // A menu row: [check/icon] text [submenu arrow]
    component MenuRow: Rectangle {
        id: row
        property string label
        property string icon
        property string leading
        property string trailing
        signal activated

        width: parent?.width ?? 0
        implicitWidth: rowContent.implicitWidth + 20
        implicitHeight: 30
        radius: 6
        color: mouse.containsMouse ? Theme.surface : "transparent"

        Row {
            id: rowContent
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                visible: row.leading !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: row.leading
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: 14
            }
            IconImage {
                visible: row.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: row.icon
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.label
                color: !row.enabled ? Theme.muted : mouse.containsMouse ? Theme.accent : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
            // Room so the arrow doesn't overlap the text
            Item {
                width: row.trailing !== "" ? 18 : 0
                height: 1
            }
        }

        Text {
            visible: row.trailing !== ""
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.trailing
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }
}
