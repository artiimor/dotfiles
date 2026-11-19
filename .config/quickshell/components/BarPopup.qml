// Ventana que se despliega debajo de un elemento de la barra (menú de la
// bandeja, mezclador de volumen...). Se cierra con close() o haciendo clic fuera.
// El tamaño lo pone quien la usa (implicitWidth / implicitHeight).
//
//   BarPopup {
//       id: popup
//       target: icono
//       implicitWidth: 200; implicitHeight: 100
//       Text { ... }
//   }
//   // en el icono: onClicked: popup.toggle()
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

PopupWindow {
    id: root

    required property Item target
    default property alias content: box.data

    // Al hacer clic en el icono para cerrar, el clic fuera ya lo ha cerrado
    // y el toggle lo volvería a abrir. Esto lo evita.
    property real _closedAt: 0
    function open() {
        if (Date.now() - _closedAt >= 300)
            visible = true;
    }
    function close() {
        visible = false;
        _closedAt = Date.now();
    }
    function toggle() {
        visible ? close() : open();
    }

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 10
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    color: "transparent"

    // Clic fuera = cerrar
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.close()
    }

    Rectangle {
        id: box
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bgSolid
        border.width: 1
        border.color: Theme.accentDim
    }
}
