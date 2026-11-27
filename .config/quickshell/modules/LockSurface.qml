// Lo que se ve en cada pantalla al bloquear: el fondo de noche, la hora,
// la fecha, el usuario, el campo de contraseña y la batería (como hyprlock).
import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.services

Item {
    id: root
    anchors.fill: parent

    // Fondo: el Pepe de noche (sin el sol del escritorio), nítido y apenas oscurecido
    // para que la hora y la contraseña se sigan leyendo
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        brightness: -0.15
    }

    // Texto sobre el fondo de noche (fecha, usuario, batería): con un tema claro
    // (o Mac claro) el fg/muted del tema es oscuro y no se leería, así que va casi
    // blanco y con sombra
    readonly property bool lightText: Theme.themeLight || Theme.macLight
    readonly property color wallFg: lightText ? "#f5f5f7" : Theme.fg
    readonly property color wallMuted: lightText ? "#d8d8de" : Theme.muted

    // La sombra de esos textos (y de la hora, siempre)
    Component {
        id: shadow
        MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.6
            shadowOpacity: 0.6
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Hora
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -180
        text: Qt.formatTime(clock.date, "HH:mm")
        color: Theme.accent
        font.family: Theme.font
        font.pixelSize: 110
        font.bold: true
        layer.enabled: true
        layer.effect: shadow
    }

    // Fecha
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -105
        text: clock.date.toLocaleDateString(Qt.locale(), I18n.dateFormat(true))
        color: root.wallMuted
        font.family: Theme.font
        font.pixelSize: 20
        layer.enabled: root.lightText
        layer.effect: shadow
    }

    // Usuario
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -15
        text: "󰀄  " + Quickshell.env("USER")
        color: root.wallFg
        font.family: Theme.font
        font.pixelSize: 16
        font.bold: true
        layer.enabled: root.lightText
        layer.effect: shadow
    }

    // ── Contraseña ────────────────────────────────────────
    Rectangle {
        id: field
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 40
        width: 300
        height: 50
        radius: Theme.radius

        // Borde: degradado del acento; amarillo comprobando o con Bloq Mayús; rojo si falla
        readonly property color stateColor: Lock.failed ? Theme.red
            : Lock.checking || Lock.capsLock ? Theme.yellow
            : "transparent"
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: field.stateColor.a > 0 ? field.stateColor : Theme.accentDim }
            GradientStop { position: 1; color: field.stateColor.a > 0 ? field.stateColor : Theme.accent }
        }

        // Tiembla al fallar
        SequentialAnimation {
            id: shake
            running: false
            loops: 2
            NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: 40 }
            NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: 80 }
            NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
        }
        Connections {
            target: Lock
            function onAttemptsChanged() { if (Lock.attempts > 0) shake.start(); }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Theme.radius - 2
            // Como Theme.bg, pero 0.85 también en Modo Mac (allí Theme.bg es 0.88)
            color: Theme.withAlpha(Theme.bgSolid, 0.85)

            // Puntos, uno por letra
            Row {
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: Lock.password.length
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.fg
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: Lock.password === ""
                text: Lock.checking ? I18n.tr("Checking...")
                    : Lock.failed ? `${Lock.error} (${Lock.attempts})`
                    : Lock.capsLock ? I18n.tr("Caps Lock on")
                    : I18n.tr("Password...")
                color: Lock.failed ? Theme.red : Lock.capsLock || Lock.checking ? Theme.yellow : Theme.muted
                font.family: Theme.font
                font.pixelSize: 14
                font.italic: Lock.failed
            }
        }

        // Recibe el teclado (invisible: lo que se ve son los puntos)
        TextInput {
            id: input
            anchors.fill: parent
            opacity: 0
            focus: true
            // Al escribir, el texto pasa a Lock.password; y si Lock lo vacía
            // (tras un intento), se vacía aquí también
            Connections {
                target: Lock
                function onPasswordChanged() {
                    if (input.text !== Lock.password)
                        input.text = Lock.password;
                }
            }
            onTextChanged: {
                if (text !== Lock.password) {
                    Lock.password = text;
                    Lock.failed = false;
                }
            }
            onAccepted: Lock.submit()
            Keys.onPressed: e => {
                Lock.checkCapsLock();
                if (e.key === Qt.Key_Escape) {
                    Lock.password = "";
                    e.accepted = true;
                }
            }
            Component.onCompleted: forceActiveFocus()
        }
    }

    // Batería, abajo a la derecha
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 30
        visible: Battery.present
        text: "󰁹  " + Battery.percent + "%"
        color: root.wallMuted
        font.family: Theme.font
        font.pixelSize: 16
        font.bold: true
        layer.enabled: root.lightText
        layer.effect: shadow
    }
}
