import QtQuick

// Control Center icon (two switches) made of pixel-aligned rectangles so it looks sharp.
Item {
    property color color: Theme.text
    implicitWidth: 16
    implicitHeight: 14

    Rectangle {
        x: 0; y: 0; width: 16; height: 6; radius: 3
        color: "transparent"; border.color: parent.color; border.width: 1.2
        Rectangle { x: 11; y: 1; width: 4; height: 4; radius: 2; color: parent.border.color }
    }
    Rectangle {
        x: 0; y: 8; width: 16; height: 6; radius: 3
        color: "transparent"; border.color: parent.color; border.width: 1.2
        Rectangle { x: 1; y: 1; width: 4; height: 4; radius: 2; color: parent.border.color }
    }
}
