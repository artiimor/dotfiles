// Desktop-mode dock (config/desktopmode.lua in Hyprland). It only shows
// on screens whose active workspace is in desktop mode.
// Shows that workspace's windows and the minimized ones (dimmer).
//   click on a window          brings it to the front
//   click on the active window minimizes it
//   click on a minimized one   restores it on this workspace
// Auto-hides: appears when the mouse rests a moment on the bottom edge.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

Variants {
    id: root

    model: Quickshell.screens

    PanelWindow {
        id: dock

        required property ShellScreen modelData
        readonly property HyprlandWorkspace workspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null
        readonly property var windows: Hyprland.toplevels.values.filter(t =>
            t.workspace && (t.workspace.id === workspace?.id || t.workspace.name === "special:minimized"))

        screen: modelData
        visible: workspace !== null && DesktopMode.workspaces.includes(workspace.name)
        anchors.bottom: true
        // Extra margin around the dock: while visible, the mouse can stray a bit without hiding it
        readonly property int slack: 40
        implicitWidth: box.width + Theme.gap * 2 + slack * 2
        implicitHeight: box.height + Theme.gap * 2 + slack
        color: "transparent"
        WlrLayershell.namespace: "quickshell-dock"
        // Hidden it reserves no space: windows use the whole screen
        exclusionMode: ExclusionMode.Ignore
        // Hidden it only captures the edge strip; the rest lets the mouse through
        mask: Region { item: dock.shown ? area : edge }

        property bool shown: false

        Timer {
            interval: 250
            running: areaHover.hovered && !dock.shown
            onTriggered: dock.shown = true
        }

        Timer {
            interval: 400
            running: dock.shown && !areaHover.hovered
            onTriggered: dock.shown = false
        }

        // Only a mask: when hidden, areaHover only sees the mouse in this strip
        Item {
            id: edge
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
        }

        // The dock goes inside area: so its HoverHandler stays active even when
        // the mouse is over the buttons (their MouseAreas don't steal the hover)
        Item {
            id: area
            anchors.fill: parent
            HoverHandler { id: areaHover }

            Rectangle {
                id: box
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dock.shown ? Theme.gap : -height
                width: Math.max(row.implicitWidth + 16, 64)
                height: 56
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: Theme.border

                Behavior on anchors.bottomMargin {
                    NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
                }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        // ScriptModel keeps the delegates of the windows that remain
                        model: ScriptModel { values: dock.windows }

                        Item {
                            id: app

                            required property HyprlandToplevel modelData
                            readonly property string appId: modelData.wayland?.appId ?? modelData.lastIpcObject?.class ?? ""
                            readonly property string target: "address:0x" + modelData.address.replace(/^0x/, "")
                            readonly property bool minimized: modelData.workspace?.name === "special:minimized"
                            readonly property bool active: modelData.activated && !minimized

                            width: 44
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radius - 2
                                color: mouse.containsMouse ? Theme.surface : "transparent"
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                sourceSize: Qt.size(60, 60)
                                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(app.appId)?.icon ?? app.appId, "application-x-executable")
                                opacity: app.minimized ? 0.4 : 1
                            }

                            // Small line below: longer on the active window
                            Rectangle {
                                visible: !app.minimized
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                height: 2
                                radius: 1
                                width: app.active ? 14 : 4
                                color: app.active ? Theme.accent : Theme.muted

                                Behavior on width {
                                    NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const win = `window = "${app.target}"`;
                                    if (app.minimized)
                                        Hypr.dispatch(`hl.dsp.window.move({ workspace = "${dock.workspace.name}", follow = false, ${win} })`,
                                                     `hl.dsp.focus({ ${win} })`, `hl.dsp.window.bring_to_top()`);
                                    else if (app.active)
                                        Hypr.dispatch(`hl.dsp.window.move({ workspace = "special:minimized", follow = false, ${win} })`);
                                    else
                                        Hypr.dispatch(`hl.dsp.focus({ ${win} })`, `hl.dsp.window.bring_to_top()`);
                                }
                            }

                            Tooltip {
                                target: app
                                above: true
                                text: app.modelData.title
                                show: mouse.containsMouse
                            }
                        }
                    }
                }
            }
        }
    }
}
