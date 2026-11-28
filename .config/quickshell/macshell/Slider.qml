import QtQuick

// Thick slider from the macOS Control Center, with the icon inside the bar.
Item {
    id: s
    property real value: 0.5
    property string icon: "sun"
    property real iconLevel: 1
    property bool iconOff: false
    signal moved(real v)
    signal iconClicked()

    // width of the icon area, on the left: there the click goes to the icon
    // (mute) and doesn't move the value
    readonly property int iconZone: 26

    implicitHeight: 24

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.tint(0.14)
        clip: true
        Rectangle {
            width: Math.max(track.height, track.width * Math.max(0, Math.min(1, s.value)))
            height: parent.height
            radius: height / 2
            color: Theme.sliderFill
        }
    }
    // contrast outline, above the fill (the track clips its children)
    Rectangle {
        anchors.fill: track
        radius: track.radius
        color: "transparent"
        border.width: Theme.outlineWidth
        border.color: Theme.separator
        z: 1
    }
    Glyph {
        x: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14
        name: s.icon
        level: s.iconLevel
        off: s.iconOff
        color: "#3a3a3c"
        z: 2
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: s.iconClicked() }
    }
    MouseArea {
        anchors.fill: parent
        anchors.leftMargin: s.iconZone
        preventStealing: true
        function set(mx) {
            const v = Math.max(0, Math.min(1, (mx + s.iconZone) / track.width));
            s.moved(v);
        }
        onPressed: m => set(m.x)
        onPositionChanged: m => { if (pressed) set(m.x); }
    }
}
