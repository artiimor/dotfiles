// La barra de una pantalla. Aquí se decide qué módulos van en cada lado.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules

PanelWindow {
    id: bar

    // Variants (en shell.qml) rellena esto con la pantalla que toca
    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    // La ventana va pegada al borde para que el degradado llegue arriba del todo;
    // el hueco de antes ahora son márgenes del contenido
    implicitHeight: Theme.barHeight + Theme.gap
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"

    // Fondo: oscuro arriba y transparente abajo, sin recuadros
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(Theme.bgSolid.r, Theme.bgSolid.g, Theme.bgSolid.b, 0.75) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: Theme.gap
        anchors.leftMargin: Theme.gap
        anchors.rightMargin: Theme.gap

        // Izquierda
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gap

            Workspaces { screen: bar.modelData }
            Media {}
        }

        // Centro
        Center {
            anchors.centerIn: parent
            bar: bar
        }

        // Derecha
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gap

            // Se esconde mientras el cajón de Status la tapa
            Tray {
                opacity: status.drawerOpen ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            }
            Status { id: status }
        }
    }
}
