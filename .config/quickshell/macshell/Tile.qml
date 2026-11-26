import QtQuick
import QtQuick.Layouts

// Módulo redondeado dentro de los popups y de la ventana Network (bloques del
// Control Center, grupos de filas). Los hijos van en una columna con margen.
Rectangle {
    id: tile
    default property alias content: col.data
    property alias spacing: col.spacing
    property int padding: 10

    implicitHeight: col.implicitHeight + 2 * padding
    radius: 12
    color: Theme.tint(0.07)
    border.color: Theme.tint(0.06)
    border.width: 1
    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: tile.padding
        spacing: 8
    }
}
