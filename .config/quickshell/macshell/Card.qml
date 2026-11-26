pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

// Una tarjeta de notificación al estilo macOS.
Item {
    id: card

    required property Notification notif
    property bool popup: true
    signal timedOut()

    readonly property bool hovered: hover.hovered
    readonly property bool critical: notif && notif.urgency === NotificationUrgency.Critical
    readonly property var actionList: notif ? notif.actions.filter(a => a.identifier !== "default") : []
    readonly property var defaultAction: notif ? notif.actions.find(a => a.identifier === "default") : null

    // para que la ventana difumine justo detrás de la tarjeta (Theme.cardBlurs)
    readonly property Region blur: Region { item: bg; radius: Theme.radius }

    implicitWidth: Theme.width
    implicitHeight: bg.height

    HoverHandler { id: hover }

    Timer {
        interval: Theme.popupTimeout
        // al pasar el ratón se para y al salir vuelve a empezar de cero, como en macOS
        running: card.popup && !card.hovered && !card.critical
        onTriggered: card.timedOut()
    }

    Rectangle {
        id: bg
        width: parent.width
        height: content.implicitHeight + 24
        radius: Theme.radius
        color: card.hovered ? Theme.cardHover : Theme.card
        border.color: Theme.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        TapHandler {
            onTapped: {
                if (card.defaultAction) card.defaultAction.invoke();
                if (card.popup) card.timedOut();
            }
        }

        RowLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            Item {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 38; implicitHeight: 38
                Image {
                    id: appIcon
                    anchors.fill: parent
                    sourceSize: Qt.size(76, 76)
                    smooth: true
                    source: {
                        const n = card.notif;
                        if (!n) return "";
                        if (n.image && !n.appIcon) return n.image;
                        const name = n.appIcon || (n.desktopEntry ? n.desktopEntry : "");
                        return Quickshell.iconPath(name, "dialog-information");
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: card.notif ? (card.notif.summary || card.notif.appName) : ""
                        color: Theme.text
                        font.weight: Font.DemiBold
                        font.pointSize: 10
                        elide: Text.ElideRight
                    }
                    Text {
                        text: card.notif ? Theme.ago(card.notif.id) : ""
                        color: Theme.dim
                        font.pointSize: 8.5
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: card.notif ? card.notif.body : ""
                    color: Theme.text
                    opacity: 0.85
                    font.pointSize: 9.5
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    linkColor: Theme.accent
                    onLinkActivated: link => Qt.openUrlExternally(link)
                    maximumLineCount: card.hovered ? 12 : 2
                    elide: Text.ElideRight
                }

                // los botones de acción aparecen al pasar el ratón
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: card.hovered && card.actionList.length > 0
                    spacing: 6
                    Repeater {
                        model: card.actionList
                        delegate: PillButton {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1   // todos del mismo ancho
                            implicitHeight: 26
                            radius: 8
                            pointSize: 9
                            text: modelData.text
                            onTapped: {
                                modelData.invoke();
                                if (card.popup) card.timedOut();
                            }
                        }
                    }
                }
            }
        }
    }

    // botón de cerrar, arriba a la izquierda, solo al pasar el ratón
    Rectangle {
        x: -6; y: -6
        width: 20; height: 20; radius: 10
        color: closeHover.hovered ? Theme.closeButtonHover : Theme.closeButton
        border.color: Theme.border
        opacity: card.hovered ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        HoverHandler { id: closeHover }
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: card.notif.dismiss() }
        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Theme.text
            font.pointSize: 7
            font.bold: true
        }
    }
}
