// Una "isla": cada grupo de módulos de la barra. Ya no lleva recuadro (la barra
// tiene un degradado detrás para que se lea); solo coloca su contenido en fila.
import QtQuick
import qs

Rectangle {
    id: root

    default property alias content: row.data
    property int padding: 15
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.radius
    color: "transparent"
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
    }

    Row {
        id: row
        anchors.centerIn: parent
        height: parent.height
    }
}
