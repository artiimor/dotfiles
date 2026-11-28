// Simple slider (0–1). Drag, click or use the wheel.
//   Slider { value: 0.5; onMoved: v => ... }
// With enabled: false it is only drawn (the OSD)
import QtQuick
import qs

Item {
    id: root

    property real value: 0
    // false: the fill looks dimmed (e.g. muted), but it still responds
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

            // While dragging, no animation: the fill follows the mouse
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
        // 120 = one wheel step = 5 %; the touchpad sends smaller steps.
        // Above 100 %, see Theme.wheelStep
        onWheel: w => {
            const v = Theme.wheelStep(root.value, w.angleDelta.y / 120 * 0.05);
            if (v !== root.value)
                root.moved(v);
        }
    }
}
