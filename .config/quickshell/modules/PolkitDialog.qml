// Agente de polkit: la ventana que pide tu contraseña cuando algo necesita
// permisos (pkexec, montar discos, cambiar cosas del sistema...).
// Sustituye a hyprpolkitagent. Enter: autenticar · Esc: cancelar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs

Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property AuthFlow flow: agent.flow

    // Pantalla entera oscurecida con el diálogo en el centro
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: agent.isActive && root.flow !== null

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: Qt.rgba(0, 0, 0, 0.45)

        onVisibleChanged: if (visible) {
            input.text = "";
            input.forceActiveFocus();
        }

        function submit() {
            if (root.flow && root.flow.isResponseRequired)
                root.flow.submit(input.text);
            input.text = "";
        }
        function cancel() {
            root.flow?.cancelAuthenticationRequest();
        }

        Rectangle {
            anchors.centerIn: parent
            width: 420
            implicitHeight: column.implicitHeight + 40
            radius: Theme.radius
            color: Theme.bgSolid
            border.width: 1
            border.color: Theme.accentDim

            ColumnLayout {
                id: column
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 12

                RowLayout {
                    spacing: 12

                    Text {
                        text: "󰒃"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: 28
                    }
                    Text {
                        text: "Autenticación necesaria"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                // Qué se está pidiendo (lo escribe la app)
                Text {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    text: "󰀄  " + (root.flow?.selectedIdentity?.displayName ?? Quickshell.env("USER"))
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }

                // Campo de contraseña
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: Theme.surface
                    border.width: 1
                    border.color: root.flow?.supplementaryIsError ? Theme.red : Theme.accent

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 14
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        clip: true
                        focus: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !input.text
                            text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Contraseña"
                            color: Theme.muted
                            font: input.font
                        }

                        onAccepted: win.submit()
                        Keys.onEscapePressed: win.cancel()
                    }
                }

                // Error o aviso (p. ej. contraseña incorrecta)
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    wrapMode: Text.Wrap
                    color: root.flow?.supplementaryIsError ? Theme.red : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    DialogButton {
                        text: "Cancelar"
                        onClicked: win.cancel()
                    }
                    DialogButton {
                        text: "Autenticar"
                        primary: true
                        onClicked: win.submit()
                    }
                }
            }
        }
    }

    component DialogButton: Rectangle {
        property alias text: label.text
        property bool primary: false
        signal clicked

        implicitWidth: label.implicitWidth + 28
        implicitHeight: 32
        radius: 7
        color: primary ? (mouse.containsMouse ? Theme.accent : Theme.accentDim)
            : (mouse.containsMouse ? Theme.surface : "transparent")
        border.width: primary ? 0 : 1
        border.color: Theme.border

        Text {
            id: label
            anchors.centerIn: parent
            color: parent.primary ? Theme.bgSolid : Theme.fg
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
