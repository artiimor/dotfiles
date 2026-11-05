// Barra deslizante sencilla (0–1). Arrastra, haz clic o usa la rueda.
//   Slider { value: 0.5; onMoved: v => ... }
import QtQuick
import qs

Item {
    id: root

    property real value: 0
    property bool enabled: true
    signal moved(real value)

    implicitWidth: 220
    implicitHeight: 20

    function set(v) { root.moved(Math.max(0, Math.min(1, v))); }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: Theme.surface

        Rectangle {
            height: parent.height
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
            radius: 4
            opacity: root.enabled ? 1 : 0.4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accentDim }
                GradientStop { position: 1; color: Theme.accent }
            }

            Behavior on width {
                NumberAnimation { duration: 100 }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.set(m.x / width)
        onPositionChanged: m => { if (pressed) root.set(m.x / width); }
        onWheel: w => root.set(root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
