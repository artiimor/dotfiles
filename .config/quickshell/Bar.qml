// La barra de una pantalla. Aquí se decide qué módulos van en cada lado.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules
import qs.services

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
    // La ventana va pegada al borde para que el fondo definido llegue arriba del
    // todo; el hueco de antes ahora son márgenes del contenido
    implicitHeight: Theme.barHeight + Theme.gap
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"

    // Fondo: por defecto no hay, solo los iconos (en claro u oscuro según el
    // fondo de pantalla, ver TopBar). Doble clic en un hueco vacío de la barra
    // la "define": fondo liso casi opaco y una línea fina abajo. Se guarda en
    // TopBar (sobrevive a los reinicios)
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.bgSolid, 0.95)
        opacity: TopBar.solidBackground ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.border
        }
    }

    // Detrás del contenido: los clics en iconos, workspaces y bandeja van a sus
    // propias MouseArea; aquí solo llega lo que cae en un hueco vacío
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onDoubleClicked: TopBar.toggleBackground()
    }

    Item {
        anchors.fill: parent

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
}
