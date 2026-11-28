import QtQuick

// Clickable bar area with the subtle macOS pill on hover or when active.
Item {
    id: btn
    property bool active: false
    default property alias content: holder.data
    signal clicked(var mouse)
    // wheel: only if scrollable (otherwise the wheel passes through). One step per
    // notch (120); touchpads and high-resolution mice send fractions that add up
    property bool scrollable: false
    signal scrolled(int steps)   // > 0 arriba, < 0 abajo
    property real _wheelAcc: 0

    implicitWidth: holder.childrenRect.width + 14
    implicitHeight: 22

    // distance from this button's right edge to the screen's right edge
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
        onWheel: w => {
            if (!btn.scrollable) { w.accepted = false; return; }
            btn._wheelAcc += w.angleDelta.y;
            const steps = Math.trunc(btn._wheelAcc / 120);
            if (steps !== 0) {
                btn._wheelAcc -= steps * 120;
                btn.scrolled(steps);
            }
        }
        onExited: btn._wheelAcc = 0
    }
}
