// Una notificación: se usa tanto en los popups como en el panel.
// Clic: acción por defecto (abrir la app) · Botón X: descartar
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.components
import qs.services

// El rectángulo de fuera es la barra de color de la izquierda (verde, gris
// si es poco importante, rojo si es crítica); el de dentro, la tarjeta.
Rectangle {
    id: root

    required property Notification modelData
    readonly property Notification n: modelData
    property bool popup: false

    readonly property bool critical: n.urgency === NotificationUrgency.Critical
    readonly property color accent: critical ? Theme.red
        : n.urgency === NotificationUrgency.Low ? Theme.muted
        : Theme.accent

    implicitWidth: 400
    implicitHeight: content.implicitHeight + 20
    radius: Theme.radius
    color: accent

    // ── Tiempo en pantalla del popup (como en swaync) ──────
    // Baja: 4 s · Normal: 6 s · Crítica: hasta que la cierres.
    // Si pasas el ratón por encima, se espera.
    readonly property int timeout: critical ? 0
        : n.urgency === NotificationUrgency.Low ? 4000
        : 6000
    Timer {
        interval: root.timeout
        running: root.popup && root.timeout > 0 && !hover.hovered
        onTriggered: Notifs.hidePopup(root.n)
    }

    // Entrada deslizando desde la derecha
    x: popup ? 420 : 0
    Component.onCompleted: x = 0
    Behavior on x {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 3
        radius: Theme.radius
        color: hover.hovered ? Theme.surface : Theme.bgSolid
        border.width: 1
        border.color: root.critical ? Theme.red : Theme.border

        Behavior on color {
            ColorAnimation { duration: Theme.anim }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const def = root.n.actions.find(a => a.identifier === "default");
            if (def)
                def.invoke();
            if (root.popup)
                Notifs.hidePopup(root.n);
        }
    }

    Row {
        id: content
        x: 13
        y: 10
        width: parent.width - 23
        spacing: 10

        // Imagen de la notificación o, si no trae, el icono de la app
        IconImage {
            id: icon
            readonly property string src: {
                const n = root.n;
                if (n.image)
                    return n.image;
                if (!n.appIcon)
                    return "";
                if (n.appIcon.startsWith("/"))
                    return "file://" + n.appIcon;
                if (n.appIcon.includes("://"))
                    return n.appIcon;
                return Quickshell.iconPath(n.appIcon, true);
            }
            visible: src !== ""
            implicitSize: 48
            source: src
        }

        Column {
            width: parent.width - (icon.visible ? icon.width + parent.spacing : 0)
            spacing: 3

            // Título + hora + cerrar
            Item {
                width: parent.width
                height: summary.implicitHeight

                Text {
                    id: summary
                    width: parent.width - time.implicitWidth - close.width - 12
                    elide: Text.ElideRight
                    text: root.n.summary || root.n.appName
                    color: root.critical ? Theme.red : Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    id: time
                    anchors.right: close.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.timeAgo(root.n)
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                BarIcon {
                    id: close
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 20
                    padding: 4
                    icon: "󰅖"
                    color: hovered ? Theme.red : Theme.muted
                    onClicked: root.n.dismiss()
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.n.body
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 8
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // Botones de acción (menos la de por defecto, que es el clic)
            Flow {
                width: parent.width
                spacing: 6
                topPadding: 4
                visible: actionRepeater.count > 0

                Repeater {
                    id: actionRepeater
                    model: root.n.actions.filter(a => a.identifier !== "default")

                    Rectangle {
                        required property NotificationAction modelData
                        implicitWidth: actionLabel.implicitWidth + 20
                        implicitHeight: 26
                        radius: 7
                        color: actionMouse.containsMouse ? Theme.accentDim : Theme.surface

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                parent.modelData.invoke();
                                Notifs.hidePopup(root.n);
                            }
                        }
                    }
                }
            }
        }
    }
}
