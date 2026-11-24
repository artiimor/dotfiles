import QtQuick

// macOS-style battery: outlined body, fill proportional to charge, bolt when charging.
Item {
    id: b
    property real fraction: 1
    property bool charging: false
    property color color: Theme.text
    implicitWidth: 25
    implicitHeight: 12

    readonly property color fillColor: charging ? "#30d158"
        : fraction <= 0.15 ? "#ff453a" : color

    Rectangle {
        id: body
        width: parent.width - 3; height: parent.height
        radius: 3.5
        color: "transparent"
        border.color: b.color
        border.width: 1
        opacity: 0.55
    }
    Rectangle {
        x: 2; y: 2
        height: body.height - 4
        width: Math.max(1.5, (body.width - 4) * Math.max(0, Math.min(1, b.fraction)))
        radius: 1.8
        color: b.fillColor
    }
    Rectangle {
        x: body.width + 0.5
        anchors.verticalCenter: parent.verticalCenter
        width: 1.8; height: 4.5
        radius: 1
        color: b.color
        opacity: 0.55
    }
    Glyph {
        visible: b.charging
        name: "bolt"
        color: "white"
        width: 10; height: 10
        anchors.centerIn: body
    }
}
