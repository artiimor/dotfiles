pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Notification center: calendar and notification list on the right of the screen.
PanelWindow {
    id: center

    property bool open: false
    property var notifications: []   // tracked notifications, from oldest to newest
    signal closeRequested()
    signal clearRequested()

    visible: open
    anchors { top: true; right: true; bottom: true }
    margins { top: 4; right: 6; bottom: 6 }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "macshell-center"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"
    implicitWidth: Theme.width + 16

    BackgroundEffect.blurRegion: Region {
        regions: centerLoader.item ? centerLoader.item.blurRegions : []
    }

    // the calendar and the cards only exist while it is open
    Loader {
        id: centerLoader
        anchors.fill: parent
        anchors.margins: 8
        active: center.open
        focus: true
        sourceComponent: centerComp
    }

    Component {
        id: centerComp
        Item {
            focus: true
            Keys.onEscapePressed: center.closeRequested()

            readonly property var blurRegions: [calRegion].concat(Theme.cardBlurs(centerList))
            Region { id: calRegion; item: calCard; radius: Theme.radius }

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    id: calCard
                    Layout.fillWidth: true
                    implicitHeight: calCol.implicitHeight + 24
                    radius: Theme.radius
                    color: Theme.card
                    border.color: Theme.border

                    ColumnLayout {
                        id: calCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 6
                        Text {
                            text: Theme.locale.toString(Theme.now, "dddd").toUpperCase()
                            color: "#ff453a"
                            font.pointSize: 8.5
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: Theme.locale.toString(Theme.now, I18n.dateFormat(false))
                            color: Theme.text
                            font.pointSize: 15
                            font.weight: Font.DemiBold
                        }
                        DayOfWeekRow {
                            Layout.fillWidth: true
                            locale: Theme.locale
                            delegate: Text {
                                required property string shortName
                                text: shortName.charAt(0).toUpperCase()
                                horizontalAlignment: Text.AlignHCenter
                                color: Theme.dim
                                font.pointSize: 8
                            }
                        }
                        MonthGrid {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6 * 26
                            month: Theme.now.getMonth()
                            year: Theme.now.getFullYear()
                            locale: Theme.locale
                            delegate: Item {
                                required property var model
                                implicitHeight: 26
                                implicitWidth: 30
                                readonly property bool today: model.today
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22; height: 22; radius: 11
                                    color: parent.today ? "#ff453a" : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.model.day
                                    color: parent.today ? "white" : Theme.text
                                    opacity: parent.model.month === Theme.now.getMonth() ? 1 : 0.3
                                    font.pointSize: 9
                                    font.bold: parent.today
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("Notifications")
                        color: Theme.text
                        font.pointSize: 10
                        font.weight: Font.DemiBold
                    }
                    PillButton {
                        visible: centerList.count > 0
                        implicitHeight: 22
                        radius: 11
                        pointSize: 8.5
                        text: I18n.tr("Clear All")
                        onTapped: center.clearRequested()
                    }
                }

                ListView {
                    id: centerList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    topMargin: 6
                    model: ScriptModel { values: center.notifications.slice().reverse() }
                    delegate: Card {
                        required property var modelData
                        notif: modelData
                        popup: false
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 24
                        visible: centerList.count === 0
                        text: I18n.tr("No Notifications")
                        color: Theme.dim
                        font.pointSize: 10
                    }
                }
            }
        }
    }
}
