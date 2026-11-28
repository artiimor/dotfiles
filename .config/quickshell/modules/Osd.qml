// Volume, microphone and brightness OSD: replaces swayosd. Shows up at the top
// right, under the bar, like in macOS, whenever they change (with the keys,
// the wheel on the bar...).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

PanelWindow {
    id: osd

    screen: Theme.focusedScreen
    visible: shown || box.opacity > 0

    anchors.top: true
    anchors.right: true
    margins.top: Theme.gap
    margins.right: Theme.gap * 2
    // 0 = reserves no space but respects the bars' (sits below them)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    // Empty region = clicks go through it
    mask: Region {}

    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight
    color: "transparent"

    property bool shown: false
    property string icon
    property real value: 0
    property bool muted: false

    function show(icon, value, muted) {
        if (!armed)
            return;
        osd.icon = icon;
        osd.value = value;
        osd.muted = muted;
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.shown = false
    }

    // The initial values are loaded at start-up: that must not show the OSD
    property bool armed: false
    Timer {
        interval: 1500
        running: true
        onTriggered: osd.armed = true
    }

    // ── What triggers it ────────────────────────────────────
    // The mic (the output is already tracked by Audio)
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [osd.source] }

    function showVolume() {
        show(Audio.icon, Audio.volume, Audio.muted);
    }

    // Only changes of the current output, not a change of output
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() { osd.showVolume(); }
        function onMutedChanged() { osd.showVolume(); }
    }

    Connections {
        target: osd.source?.audio ?? null
        function onMutedChanged() {
            const a = osd.source.audio;
            osd.show(a.muted ? "󰍭" : "󰍬", a.volume, a.muted);
        }
    }

    Connections {
        target: Brightness
        enabled: Brightness.available
        function onPercentChanged() {
            osd.show(Brightness.icon, Brightness.percent / 100, false);
        }
    }

    // ── Aspecto ───────────────────────────────────────────
    Rectangle {
        id: box
        implicitWidth: row.implicitWidth + 40
        implicitHeight: row.implicitHeight + 28
        radius: Theme.radius
        color: Theme.bg
        border.width: 1
        border.color: Theme.frame
        opacity: osd.shown ? 1 : 0
        scale: osd.shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                horizontalAlignment: Text.AlignHCenter
                text: osd.icon
                color: Theme.accent
                opacity: osd.muted ? 0.4 : 1
                font.family: Theme.font
                font.pixelSize: 18
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: 160
                enabled: false
                value: osd.value
                active: !osd.muted
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                text: Math.round(osd.value * 100) + "%"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }
    }
}
