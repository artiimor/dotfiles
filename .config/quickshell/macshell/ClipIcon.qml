import QtQuick

// Clipboard icon made of pixel-aligned rectangles.
Item {
    property color color: Theme.text
    implicitWidth: 13
    implicitHeight: 16

    Rectangle {
        x: 0; y: 2; width: 13; height: 14; radius: 2.5
        color: "transparent"; border.color: parent.color; border.width: 1.2
    }
    Rectangle {
        x: 3.5; y: 0; width: 6; height: 4; radius: 1.5
        color: parent.color
    }
    Rectangle { x: 3; y: 8; width: 7; height: 1.2; radius: 0.6; color: parent.color; opacity: 0.8 }
    Rectangle { x: 3; y: 11; width: 5; height: 1.2; radius: 0.6; color: parent.color; opacity: 0.8 }
}
