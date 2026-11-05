// Cajón: una fila que se despliega (de 0 a su ancho) cuando `open` es true.
// Es lo que hace "drawer" en Waybar: el reloj y la flecha de sistema lo usan.
import QtQuick
import qs

Item {
    id: root

    property bool open: false
    // true: crece hacia la izquierda (anclado por la derecha), el contenido sale pegado al borde fijo
    property bool fromRight: false
    default property alias content: row.data

    implicitHeight: Theme.barHeight
    implicitWidth: open ? row.implicitWidth : 0
    clip: true
    opacity: open ? 1 : 0

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.drawerAnim; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.drawerAnim }
    }

    Row {
        id: row
        anchors.right: root.fromRight ? parent.right : undefined
        height: parent.height
    }
}
