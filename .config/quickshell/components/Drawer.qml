// Cajón: una fila que se despliega (de 0 a su ancho) mientras el ratón esté en
// la zona fija del módulo (su padre) o en el propio cajón.
// Es lo que hace "drawer" en Waybar: el reloj y la flecha de sistema lo usan.
import QtQuick
import qs

Item {
    id: root

    readonly property bool open: hover.hovered || zoneHover.hovered
    // true: crece hacia la izquierda (anclado por la derecha), el contenido sale pegado al borde fijo
    property bool fromRight: false
    default property alias content: row.data

    implicitHeight: Theme.barHeight
    implicitWidth: open ? row.implicitWidth : 0
    clip: true
    opacity: open ? 1 : 0

    HoverHandler { id: hover }
    HoverHandler { id: zoneHover; parent: root.parent }

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
