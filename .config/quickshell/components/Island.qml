// Una "isla": cada grupo de módulos de la barra. Ya no lleva recuadro (la barra
// tiene un degradado detrás para que se lea); solo coloca su contenido en fila.
import QtQuick
import qs

Item {
    id: root

    default property alias content: row.data
    property int padding: 6
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
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
