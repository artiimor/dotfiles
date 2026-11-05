// Menú del clic derecho de la bandeja, con el estilo de la barra.
// Los submenús se abren dentro del mismo menú (con "Atrás" para volver).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs

PopupWindow {
    id: root

    required property Item target   // icono de la bandeja
    property var rootMenu: null     // SystemTrayItem.menu

    // Pila de submenús abiertos; el último es el que se ve
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : rootMenu

    // Al hacer clic en el icono para cerrar, el clic fuera ya lo ha cerrado
    // y el toggle lo volvería a abrir. Esto lo evita.
    property real _closedAt: 0
    function open() {
        if (Date.now() - _closedAt < 300)
            return;
        stack = [];
        visible = true;
    }
    function close() {
        visible = false;
        _closedAt = Date.now();
    }

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 10
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight
    color: "transparent"

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.close()
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    Rectangle {
        id: box
        implicitWidth: Math.max(180, column.implicitWidth + 12)
        implicitHeight: column.implicitHeight + 12
        radius: Theme.radius
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.accentDim

        Column {
            id: column
            x: 6
            y: 6
            width: parent.width - 12

            // "Atrás" cuando estás en un submenú
            MenuRow {
                visible: root.stack.length > 0
                label: "Atrás"
                leading: "󰁍"
                onActivated: root.stack = root.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children

                Loader {
                    required property QsMenuEntry modelData
                    width: column.width
                    sourceComponent: modelData.isSeparator ? separator : entry

                    Component {
                        id: separator
                        Item {
                            implicitHeight: 9
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 12
                                height: 1
                                color: Theme.border
                            }
                        }
                    }

                    Component {
                        id: entry
                        MenuRow {
                            readonly property QsMenuEntry e: modelData
                            label: e.text.replace(/_(?!_)/g, "") // quita los "_" de los atajos de teclado
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
        }
    }

    // Una fila del menú: [marca/icono] texto [flecha de submenú]
    component MenuRow: Rectangle {
        id: row
        property string label
        property string icon
        property string leading
        property string trailing
        property bool enabled: true
        signal activated

        width: parent?.width ?? 0
        implicitWidth: rowContent.implicitWidth + 20
        implicitHeight: 30
        radius: 6
        color: mouse.containsMouse && enabled ? Theme.surface : "transparent"

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
                font.pixelSize: 13
                font.bold: true
            }
            // Hueco para que la flecha no pise el texto
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
            font.pixelSize: 13
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }
}
