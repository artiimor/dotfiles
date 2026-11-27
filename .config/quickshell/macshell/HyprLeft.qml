pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Mitad izquierda de la barra superior: workspaces 1-5 y luego el nombre de la app enfocada
// en negrita, donde iría el menú global.
// Los workspaces flotantes (modo escritorio: todos en los perfiles mac, ver desktopmode.lua) llevan
// el número dentro de una cajita redondeada; los de tiling, el número sin más.
Row {
    id: lh
    required property var screen
    spacing: 10

    readonly property HyprlandMonitor monitor: (screen ? Hyprland.monitorFor(screen) : null) ?? Hyprland.focusedMonitor
    // los ids de Hyprland son monitor*10 + n (wsFor en binds.lua)
    readonly property int base: (monitor?.id ?? 0) * 10
    readonly property int activeId: monitor?.activeWorkspace?.id ?? -1

    // ids de los workspaces en modo escritorio (flotantes), uno por línea
    property var floatingIds: []
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/desktop-workspaces"
        watchChanges: true
        printErrors: false   // no existe hasta que se usa el modo escritorio una vez
        onFileChanged: reload()
        onLoaded: lh.floatingIds = text().split("\n").filter(l => l !== "")
        onLoadFailed: lh.floatingIds = []
    }

    // ids de los workspaces con al menos una ventana
    readonly property var busyIds: Hyprland.toplevels.values.map(t => t.workspace?.id ?? -1)

    readonly property var slots: {
        const extra = busyIds.filter(id => id > base && id <= base + 10).map(id => id - base);
        const n = Math.max(5, ...extra, activeId - base);
        return Array.from({ length: Math.min(10, n) }, (_, i) => i + 1);
    }

    function goTo(target) {
        // la config de Hyprland es Lua, así que dispatch usa la sintaxis hl.dsp
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
                model: lh.slots
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
                    // workspace flotante: número dentro de una caja redondeada, como una ventanita
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
                    // puntito bajo los workspaces que tienen ventanas
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

    // nombre de la app enfocada, en negrita, como la primera entrada de la barra de menús de macOS
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
