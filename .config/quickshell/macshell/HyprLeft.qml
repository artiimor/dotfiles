pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Left half of the top bar: workspaces 1-5 and then the focused app's name
// in bold, where the global menu would go.
// Floating workspaces (desktop mode: all of them in the mac profiles, see desktopmode.lua) have
// the number inside a small rounded box; tiling ones, just the number.
Row {
    id: lh
    required property var screen
    spacing: 10

    readonly property HyprlandMonitor monitor: (screen ? Hyprland.monitorFor(screen) : null) ?? Hyprland.focusedMonitor
    // Hyprland ids are monitor*10 + n (wsFor in binds.lua)
    readonly property int base: (monitor?.id ?? 0) * 10
    readonly property int activeId: monitor?.activeWorkspace?.id ?? -1

    // ids of the desktop-mode (floating) workspaces, one per line
    property var floatingIds: []
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desktop-workspaces"
        watchChanges: true
        printErrors: false   // doesn't exist until desktop mode is used once
        onFileChanged: reload()
        onLoaded: lh.floatingIds = text().split("\n").filter(l => l !== "")
        onLoadFailed: lh.floatingIds = []
    }

    // ids of the workspaces with at least one window
    readonly property var busyIds: Hyprland.toplevels.values.map(t => t.workspace?.id ?? -1)

    readonly property var slots: {
        const extra = busyIds.filter(id => id > base && id <= base + 10).map(id => id - base);
        const n = Math.max(5, ...extra, activeId - base);
        return Array.from({ length: Math.min(10, n) }, (_, i) => i + 1);
    }

    function goTo(target) {
        // the Hyprland config is Lua, so dispatch uses the hl.dsp syntax
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = "${target}" })`]);
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: wsRow.implicitWidth
        implicitHeight: 22

        Row {
            id: wsRow
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                // ScriptModel keeps the delegates of the slots that remain
                model: ScriptModel { values: lh.slots }
                delegate: MouseArea {
                    id: ws
                    required property int modelData
                    readonly property int wsId: lh.base + modelData
                    readonly property bool active: wsId === lh.activeId
                    readonly property bool busy: lh.busyIds.includes(wsId)
                    readonly property bool floating: lh.floatingIds.includes(String(wsId))
                    width: floating ? 26 : 20
                    height: label.implicitHeight + 5
                    onClicked: lh.goTo(wsId)
                    Text {
                        id: label
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        text: ws.modelData
                        color: ws.active ? Theme.wsActive : Theme.text
                        opacity: ws.active ? 1.0 : (ws.busy ? 0.9 : 0.3)
                        font.bold: ws.active
                        font.pointSize: 10
                    }
                    // floating workspace: number inside a rounded box, like a small window
                    Rectangle {
                        visible: ws.floating
                        anchors.centerIn: label
                        width: label.implicitWidth + 9
                        height: label.implicitHeight - 1
                        radius: 3
                        color: "transparent"
                        border.width: 1
                        border.color: label.color
                        opacity: label.opacity
                    }
                    // small dot under the workspaces that have windows
                    Rectangle {
                        visible: ws.busy
                        width: 3; height: 3; radius: 1.5
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        color: label.color
                        opacity: label.opacity
                    }
                }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => lh.goTo(e.angleDelta.y > 0 ? "m-1" : "m+1")
        }
    }

    // focused app name, in bold, like the first entry of the macOS menu bar
    Text {
        anchors.verticalCenter: parent.verticalCenter
        readonly property var win: ToplevelManager.activeToplevel
        readonly property string appId: win?.appId ?? ""
        readonly property var entry: appId ? DesktopEntries.heuristicLookup(appId) : null
        text: !win ? I18n.tr("Desktop") : (entry?.name || (appId ? appId.charAt(0).toUpperCase() + appId.slice(1) : ""))
        color: Theme.text
        font.pointSize: 10
        font.bold: true
    }
}
