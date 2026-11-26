// Barra deslizante sencilla (0–1). Arrastra, haz clic o usa la rueda.
//   Slider { value: 0.5; onMoved: v => ... }
// Con enabled: false solo se dibuja (el OSD)
import QtQuick
import qs

Item {
    id: root

    property real value: 0
    // false: el relleno se ve apagado (p. ej. silenciado), pero sigue respondiendo
    property bool active: true
    signal moved(real value)

    implicitWidth: 220
    implicitHeight: 20

    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: Theme.surface

        Rectangle {
            height: parent.height
            width: Math.max(height, parent.width * root.clamp(root.value))
            radius: 4
            opacity: root.active ? 1 : 0.4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accentDim }
                GradientStop { position: 1; color: Theme.accent }
            }

            // Al arrastrar, sin animación: el relleno va pegado al ratón
            Behavior on width {
                enabled: !mouse.pressed
                NumberAnimation { duration: 100 }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.moved(root.clamp(m.x / width))
        onPositionChanged: m => { if (pressed) root.moved(root.clamp(m.x / width)); }
        // 120 = un paso de rueda = 5 %; el touchpad manda pasos más pequeños.
        // Por encima del 100 % (Pipewire lo permite) subir no lo baja a 100
        onWheel: w => {
            const d = w.angleDelta.y / 120 * 0.05;
            if (d < 0 || (d > 0 && root.value < 1))
                root.moved(root.clamp(root.value + d));
        }
    }
}
