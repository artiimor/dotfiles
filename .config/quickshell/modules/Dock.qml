// Dock del modo escritorio (config/desktopmode.lua en Hyprland). Solo aparece
// en las pantallas cuyo workspace activo está en modo escritorio.
// Enseña las ventanas de ese workspace y las minimizadas (más apagadas).
//   clic en una ventana        la trae al frente
//   clic en la ventana activa  la minimiza
//   clic en una minimizada     la recupera en este workspace
// Se oculta solo: aparece al dejar el ratón un ratillo en el borde de abajo.
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
        // Margen extra alrededor del dock: visible, el ratón puede salirse un poco sin que se esconda
        readonly property int slack: 40
        implicitWidth: box.width + Theme.gap * 2 + slack * 2
        implicitHeight: box.height + Theme.gap * 2 + slack
        color: "transparent"
        WlrLayershell.namespace: "quickshell-dock"
        // Oculto no reserva hueco: las ventanas usan toda la pantalla
        exclusionMode: ExclusionMode.Ignore
        // Escondido solo captura la tira del borde; el resto deja pasar el ratón
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

        // Solo sirve de máscara: escondido, areaHover solo ve el ratón en esta tira
        Item {
            id: edge
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
        }

        function dispatch(...cmds) {
            // La config de Hyprland es Lua: cada orden es una expresión hl.dsp
            Quickshell.execDetached(["hyprctl", "--batch", cmds.map(c => "dispatch " + c).join(" ; ")]);
        }

        // El dock va dentro de area: así su HoverHandler sigue activo aunque
        // el ratón esté sobre los botones (sus MouseArea no le roban el hover)
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
                        model: dock.windows

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

                            // Rayita debajo: más larga en la ventana activa
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
                                        dock.dispatch(`hl.dsp.window.move({ workspace = "${dock.workspace.name}", follow = false, ${win} })`,
                                                      `hl.dsp.focus({ ${win} })`, `hl.dsp.window.bring_to_top()`);
                                    else if (app.active)
                                        dock.dispatch(`hl.dsp.window.move({ workspace = "special:minimized", follow = false, ${win} })`);
                                    else
                                        dock.dispatch(`hl.dsp.focus({ ${win} })`, `hl.dsp.window.bring_to_top()`);
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
