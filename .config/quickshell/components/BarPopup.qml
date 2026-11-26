// Ventana que se despliega debajo de un elemento de la barra (menú de la
// bandeja, mezclador de volumen...). Se cierra con close(), con Escape o haciendo clic fuera.
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
        if (Date.now() - _closedAt >= Theme.reopenDelay)
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
    anchor.rect.height: target.height + Theme.popupGap
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    color: "transparent"

    // Clic fuera = cerrar. Además le da el teclado al popup (para Escape).
    // Con `visible` el grab se pide antes de que exista la superficie y no llega a activarse.
    HyprlandFocusGrab {
        windows: [root]
        active: root.backingWindowVisible
        onCleared: root.close()
    }

    PopupBox {
        id: box
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }
}
