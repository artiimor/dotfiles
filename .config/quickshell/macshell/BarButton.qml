import QtQuick

// Zona pulsable de la barra con la píldora sutil de macOS al pasar el ratón o estar activa.
Item {
    id: btn
    property bool active: false
    default property alias content: holder.data
    signal clicked(var mouse)

    implicitWidth: holder.childrenRect.width + 14
    implicitHeight: 22

    // distancia del borde derecho de este botón al borde derecho de la pantalla
    function rightDistance() {
        const p = btn.mapToItem(null, btn.width, 0);
        return btn.Window.window ? btn.Window.window.width - p.x : 0;
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Theme.ink
        opacity: btn.active ? 0.20 : (mouse.containsMouse ? 0.12 : 0)
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }
    Item {
        id: holder
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => btn.clicked(m)
    }
}
