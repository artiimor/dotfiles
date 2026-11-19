// OSD de volumen, micrófono y brillo: sustituye a swayosd. Aparece arriba a la
// derecha, bajo la barra, como en macOS, cada vez que cambian (con las teclas,
// la rueda en la barra...).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs
import qs.services

PanelWindow {
    id: osd

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: shown || box.opacity > 0

    anchors.top: true
    anchors.right: true
    margins.top: Theme.gap
    margins.right: Theme.gap * 2
    // 0 = no reserva espacio pero respeta el de las barras (queda debajo)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    // Región vacía = los clics lo atraviesan
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

    // Al arrancar se cargan los valores iniciales: eso no debe sacar el OSD
    property bool armed: false
    Timer {
        interval: 1500
        running: true
        onTriggered: osd.armed = true
    }

    // ── Qué lo dispara ────────────────────────────────────
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [osd.sink, osd.source] }

    function showVolume() {
        const a = sink?.audio;
        if (!a)
            return;
        show(a.muted ? "󰝟" : ["󰕿", "󰖀", "󰕾"][Math.min(2, Math.floor(a.volume * 3))], a.volume, a.muted);
    }

    Connections {
        target: osd.sink?.audio ?? null
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
        function onPercentChanged() {
            const p = Brightness.percent;
            osd.show(["󰃞", "󰃟", "󰃠"][Math.min(2, Math.floor(p / 34))], p / 100, false);
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

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 160
                height: 8
                radius: 4
                color: Theme.surface
                opacity: osd.muted ? 0.4 : 1

                Rectangle {
                    height: parent.height
                    width: Math.max(height, parent.width * Math.min(1, osd.value))
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.accentDim }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
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
