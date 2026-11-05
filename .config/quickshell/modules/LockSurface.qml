// Lo que se ve en cada pantalla al bloquear: el fondo desenfocado, la hora,
// la fecha, el usuario, el campo de contraseña y la batería (como hyprlock).
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.UPower
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
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.6
            shadowOpacity: 0.6
        }
    }

    // Fecha
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -105
        text: clock.date.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM")
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 20
    }

    // Usuario
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -15
        text: "󰀄  " + Quickshell.env("USER")
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: 16
        font.bold: true
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

        // Borde: degradado verde; amarillo comprobando o con Bloq Mayús; rojo si falla
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
            color: Qt.rgba(Theme.bgSolid.r, Theme.bgSolid.g, Theme.bgSolid.b, 0.85)

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
                text: Lock.checking ? "Comprobando..."
                    : Lock.failed ? `${Lock.error} (${Lock.attempts})`
                    : Lock.capsLock ? "Bloq Mayús activado"
                    : "Contraseña..."
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
        visible: UPower.displayDevice?.isLaptopBattery ?? false
        text: {
            const p = UPower.displayDevice?.percentage ?? 0;
            return "󰁹  " + Math.round(p > 1 ? p : p * 100) + "%";
        }
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 16
        font.bold: true
    }
}
