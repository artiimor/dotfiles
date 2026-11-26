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

    ReopenGuard { id: guard }
    function open() {
        if (guard.canOpen())
            visible = true;
    }
    function close() {
        visible = false;
        guard.closed();
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
    // Con `visible` no llega a activarse: la ventana de un PopupWindow se crea al mostrarlo,
    // y el grab se pediría sin ella. Las PanelWindow (lanzador, panel de notificaciones)
    // ya la tienen creada aunque estén ocultas, así que a ellas les vale `visible`.
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
