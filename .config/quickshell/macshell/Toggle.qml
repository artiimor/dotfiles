import QtQuick

// Botón redondo con icono, azul si está activo (estilo Control Center), con título y subtítulo.
Item {
    id: t
    property string icon: ""
    property real iconLevel: 3
    property bool on: false
    property string title: ""
    property string subtitle: ""
    property bool hasChevron: false
    signal toggled()
    signal chevron()

    implicitHeight: 34

    Rectangle {
        id: circle
        width: 28; height: 28; radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: t.on ? Theme.accent : Theme.tint(0.14)
        Behavior on color { ColorAnimation { duration: 120 } }
        Glyph {
            anchors.centerIn: parent
            width: 15; height: 15
            name: t.icon
            level: t.iconLevel
            // encendido, blanco sobre el azul; apagado, el color del texto (en mac-light
            // el blanco casi no se ve sobre el gris claro)
            color: t.on ? "white" : Theme.text
        }
        MouseArea { anchors.fill: parent; onClicked: t.toggled() }
    }
    Column {
        anchors { left: circle.right; leftMargin: 8; right: chev.left; verticalCenter: parent.verticalCenter }
        Text {
            width: parent.width
            text: t.title
            textFormat: Text.PlainText
            color: Theme.text
            font.pointSize: 9.5
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: t.subtitle
            textFormat: Text.PlainText   // nombres de redes y dispositivos
            color: Theme.dim
            font.pointSize: 8.5
            elide: Text.ElideRight
        }
    }
    Glyph {
        id: chev
        visible: t.hasChevron
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: t.hasChevron ? 12 : 0; height: 12
        name: "chevron"
        color: Theme.dim
    }
    MouseArea {
        anchors { left: circle.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        onClicked: t.hasChevron ? t.chevron() : t.toggled()
    }
}
