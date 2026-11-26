import QtQuick
import QtQuick.Layouts

// Fila de menú estilo macOS: resaltado azul al pasar el ratón, check/icono/flecha de submenú opcionales.
Rectangle {
    id: r
    property string text: ""
    property string iconSource: ""
    property bool checkable: false
    property bool checked: false
    property bool submenu: false
    property bool enabledItem: true
    signal triggered()

    // resaltada: fondo de acento y contenido en blanco (como Spotlight), también en mac-light
    readonly property bool lit: mouse.containsMouse && enabledItem
    readonly property color fg: lit ? "white" : Theme.text

    implicitHeight: 26
    radius: 6
    color: lit ? Theme.accent : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 8
        spacing: 6
        Item {
            visible: r.checkable
            implicitWidth: 12; implicitHeight: 12
            Glyph { anchors.fill: parent; visible: r.checked; name: "check"; color: r.fg }
        }
        Image {
            visible: r.iconSource !== ""
            source: r.iconSource
            sourceSize: Qt.size(16, 16)
            Layout.preferredWidth: 16; Layout.preferredHeight: 16
        }
        Text {
            Layout.fillWidth: true
            text: r.text
            color: r.fg
            opacity: r.enabledItem ? 1 : 0.4
            font.pointSize: 9.5
            elide: Text.ElideRight
        }
        Glyph {
            visible: r.submenu
            name: "chevron"
            color: r.fg
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: if (r.enabledItem) r.triggered()
    }
}
