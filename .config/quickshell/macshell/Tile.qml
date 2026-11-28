import QtQuick
import QtQuick.Layouts

// Rounded module inside the popups and the Network window (Control
// Center blocks, row groups). Children go in a column with margin.
Rectangle {
    id: tile
    default property alias content: col.data
    property alias spacing: col.spacing
    property int padding: 10

    implicitHeight: col.implicitHeight + 2 * padding
    radius: 12
    color: Theme.tint(0.07)
    border.color: Theme.outline
    border.width: 1
    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: tile.padding
        spacing: 8
    }
}
