pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    // ── shared state ──
    property var popups: []          // notifications currently shown as banners
    property bool centerOpen: false
    property bool dnd: false
    property string popupKind: ""    // "", "cc", "wifi", "battery", "tray"
    property var popupItem: null     // SystemTrayItem for "tray"
    property real popupRight: 6      // distance from screen right edge

    function hidePopup(n) { popups = popups.filter(p => p && p !== n); }

    function togglePopup(kind, button, item) {
        centerOpen = false;
        if (popupKind === kind && popupItem === (item ?? null)) { closeAll(); return; }
        popupItem = item ?? null;
        popupRight = Math.max(6, button.rightDistance() - 14);
        popupKind = kind;
    }
    function closeAll() { popupKind = ""; popupItem = null; centerOpen = false; }

    // ───────────── notifications ─────────────
    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            Theme.stamp(n.id);
            const id = n.id;
            n.closed.connect(() => { root.hidePopup(n); Theme.forget(id); });
            const critical = n.urgency === NotificationUrgency.Critical;
            if (!root.centerOpen && (!root.dnd || critical))
                root.popups = [n].concat(root.popups.filter(p => p && p !== n)).slice(0, 4);
        }
    }

    IpcHandler {
        target: "center"
        function toggle(): void { root.popupKind = ""; root.centerOpen = !root.centerOpen; }
        function open(): void { root.centerOpen = true; }
        function close(): void { root.centerOpen = false; }
        function clear(): void { server.trackedNotifications.values.slice().forEach(n => n.dismiss()); }
    }

    IpcHandler {
        target: "bar"
        // qs -p ~/.config/quickshell/macshell ipc call bar open cc|wifi|battery
        function open(kind: string): void { root.centerOpen = false; root.popupItem = null; root.popupRight = 6; root.popupKind = kind; }
        function close(): void { root.closeAll(); }
        function debug(): string {
            return "popups=" + root.popups.length + " centerOpen=" + root.centerOpen + " dnd=" + root.dnd
                + " bannerVisible=" + bannerWin.visible + " count=" + bannerList.count
                + " tracked=" + server.trackedNotifications.values.length;
        }
    }

    IpcHandler {
        target: "spotlight"
        function toggle(): void { root.closeAll(); spotlight.toggle(); }
        function open(): void { root.closeAll(); spotlight.show(); }
        function close(): void { spotlight.close(); }
        function search(q: string): void { root.closeAll(); spotlight.show(); spotlight.setQuery(q); }
    }

    Spotlight { id: spotlight }

    IpcHandler {
        target: "power"
        function toggle(): void { root.closeAll(); spotlight.close(); powerMenu.toggle(); }
        function open(): void { root.closeAll(); spotlight.close(); powerMenu.show(); }
        function close(): void { powerMenu.close(); }
    }

    PowerMenu { id: powerMenu }

    IpcHandler {
        target: "network"
        function open(): void { root.closeAll(); root.openNetwork(); }
        function close(): void { if (netLoader.item) netLoader.item.visible = false; }
    }

    // Network window (rarely opened): built on first use
    LazyLoader { id: netLoader; NetworkSettings {} }
    function openNetwork() { netLoader.active = true; netLoader.item.show(); }

    onCenterOpenChanged: if (centerOpen) popups = []

    // ───────────── top bar ─────────────
    PanelWindow {
        id: bar
        anchors { top: true; right: true; left: true }
        exclusionMode: ExclusionMode.Auto
        // Top so fullscreen windows cover it
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "macshell-bar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        implicitHeight: 26
        implicitWidth: barRow.implicitWidth + 16

        // ── panel background + left half ──
        BackgroundEffect.blurRegion: barBlur
        Region { id: barBlur; item: barBg }
        Rectangle {
            id: barBg
            anchors.fill: parent
            color: Theme.panel   // Sur-Oscuro translucent panel (light in mac-light)
            MouseArea { anchors.fill: parent; onClicked: root.closeAll() }
        }

        HyprLeft {
            screen: bar.screen
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        }

        RowLayout {
            id: barRow
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 4

            // app tray icons (StatusNotifierItems)
            Repeater {
                model: SystemTray.items
                delegate: BarButton {
                    id: trayBtn
                    required property var modelData
                    active: root.popupKind === "tray" && root.popupItem === modelData
                    Image {
                        width: 16; height: 16
                        sourceSize: Qt.size(32, 32)
                        source: trayBtn.modelData.icon
                        smooth: true
                    }
                    onClicked: m => {
                        const it = trayBtn.modelData;
                        if (m.button === Qt.MiddleButton) it.secondaryActivate();
                        else if (m.button === Qt.RightButton || it.onlyMenu) {
                            if (it.hasMenu) root.togglePopup("tray", trayBtn, it);
                        } else { root.closeAll(); it.activate(); }
                    }
                }
            }

            BarButton {
                id: clipBtn
                active: root.popupKind === "clip"
                ClipIcon {}
                onClicked: root.togglePopup("clip", clipBtn)
            }

            BarButton {
                id: wifiBtn
                active: root.popupKind === "wifi"
                Glyph {
                    width: 18; height: 18
                    name: "wifi"
                    level: Sys.wifiLevel
                    off: !Sys.wifiOn || (!Sys.wifiNetwork)
                }
                onClicked: root.togglePopup("wifi", wifiBtn)
            }

            BarButton {
                id: batBtn
                visible: Sys.hasBattery
                active: root.popupKind === "battery"
                Row {
                    spacing: 5
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Sys.batteryFraction * 100) + " %"
                        color: Theme.text
                        font.pointSize: 9.5
                    }
                    BatteryIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        fraction: Sys.batteryFraction
                        charging: Sys.charging
                    }
                }
                onClicked: root.togglePopup("battery", batBtn)
            }

            BarButton {
                id: ccBtn
                active: root.popupKind === "cc"
                CCIcon {}
                onClicked: { Sys.refreshBrightness(); root.togglePopup("cc", ccBtn); }
            }

            BarButton {
                Glyph { width: 15; height: 15; name: "search" }
                onClicked: { root.closeAll(); spotlight.toggle(); }
            }

            BarButton {
                active: root.centerOpen
                Text {
                    text: Qt.locale("en_US").toString(Theme.now, "ddd MMM d   HH:mm")
                    color: Theme.text
                    font.pointSize: 9.5
                }
                onClicked: { root.popupKind = ""; root.centerOpen = !root.centerOpen; }
            }
        }
    }

    // ───────────── click-outside catcher ─────────────
    PanelWindow {
        visible: root.centerOpen || root.popupKind !== ""
        anchors { top: true; bottom: true; left: true; right: true }
        // leave the bar uncovered so its buttons keep working
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "macshell-catcher"
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: root.closeAll() }
    }

    // ───────────── bar popups ─────────────
    PanelWindow {
        id: popWin
        visible: root.popupKind !== ""
        anchors { top: true; right: true }
        margins { top: 4; right: root.popupRight }
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "macshell-popup"
        WlrLayershell.keyboardFocus: root.popupKind === "wifi" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"
        implicitWidth: popSurface.width + 16
        implicitHeight: popSurface.height + 16

        BackgroundEffect.blurRegion: Region { item: popSurface; radius: Theme.radius }

        Rectangle {
            id: popSurface
            x: 8; y: 8
            width: popLoader.width + 20
            height: popLoader.height + 20
            radius: Theme.radius
            color: Theme.card
            border.color: Theme.border
            focus: true
            Keys.onEscapePressed: root.closeAll()

            Loader {
                id: popLoader
                x: 10; y: 10
                readonly property var widths: ({ cc: 330, wifi: 300, battery: 290, clip: 300, tray: 260 })
                width: widths[root.popupKind] ?? 280
                height: item ? item.implicitHeight : 0
                sourceComponent: {
                    switch (root.popupKind) {
                    case "cc": return ccComp;
                    case "wifi": return wifiComp;
                    case "battery": return batComp;
                    case "tray": return trayComp;
                    case "clip": return clipComp;
                    default: return null;
                    }
                }
            }
        }

        Component {
            id: ccComp
            ControlCenter {
                dnd: root.dnd
                onToggleDnd: root.dnd = !root.dnd
                onOpenWifi: root.popupKind = "wifi"
            }
        }
        Component { id: wifiComp; WifiPanel { onDone: root.closeAll(); onOpenSettings: root.openNetwork() } }
        Component { id: batComp; BatteryPanel { onDone: root.closeAll() } }
        Component { id: clipComp; ClipboardPanel { onDone: root.closeAll() } }
        Component { id: trayComp; TrayMenu { item: root.popupItem; onDone: root.closeAll() } }
    }

    // ───────────── banners (top-right) ─────────────
    PanelWindow {
        id: bannerWin
        visible: true
        anchors { top: true; right: true }
        margins { top: 6; right: 6 }
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "macshell-notify"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        implicitWidth: Theme.width + 16
        implicitHeight: Math.max(1, bannerList.contentHeight + 16)

        mask: Region { item: bannerList }
        BackgroundEffect.blurRegion: Region {
            regions: bannerList.contentItem.children.filter(c => c.blur).map(c => c.blur)
        }

        ListView {
            id: bannerList
            x: 8; y: 8
            width: Theme.width
            height: contentHeight
            interactive: false
            spacing: 8
            model: ScriptModel { values: root.popups.filter(p => p) }

            delegate: Card {
                id: banner
                required property var modelData
                notif: modelData
                popup: true
                onTimedOut: root.hidePopup(modelData)
                property Region blur: Region { item: banner.background; radius: Theme.radius }
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: Theme.width * 0.6; to: 0; duration: 320; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; to: Theme.width; duration: 260; easing.type: Easing.InCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: 220 }
                }
            }
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }

    // ───────────── notification center ─────────────
    PanelWindow {
        id: centerWin
        visible: root.centerOpen
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

        // the calendar and the notification cards only exist while it's open
        Loader {
            id: centerLoader
            anchors.fill: parent
            anchors.margins: 8
            active: root.centerOpen
            focus: true
            sourceComponent: centerComp
        }

        Component {
            id: centerComp
            Item {
                focus: true
                Keys.onEscapePressed: root.centerOpen = false

                readonly property var blurRegions: [calRegion].concat(centerList.contentItem.children.filter(c => c.blur).map(c => c.blur))
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
                                text: Qt.locale("en_US").toString(Theme.now, "dddd").toUpperCase()
                                color: "#ff453a"
                                font.pointSize: 8.5
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: Qt.locale("en_US").toString(Theme.now, "MMMM d")
                                color: Theme.text
                                font.pointSize: 15
                                font.weight: Font.DemiBold
                            }
                            DayOfWeekRow {
                                Layout.fillWidth: true
                                locale: Qt.locale("en_US")
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
                                locale: Qt.locale("en_US")
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
                            text: "Notifications"
                            color: Theme.text
                            font.pointSize: 10
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            visible: centerList.count > 0
                            implicitWidth: clearTxt.implicitWidth + 16
                            implicitHeight: 22
                            radius: 11
                            color: clearHover.hovered ? Theme.buttonHover : Theme.button
                            HoverHandler { id: clearHover }
                            TapHandler { onTapped: server.trackedNotifications.values.slice().forEach(n => n.dismiss()) }
                            Text {
                                id: clearTxt
                                anchors.centerIn: parent
                                text: "Clear All"
                                color: Theme.text
                                font.pointSize: 8.5
                            }
                        }
                    }

                    ListView {
                        id: centerList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        topMargin: 6
                        model: ScriptModel { values: server.trackedNotifications.values.slice().reverse() }
                        delegate: Card {
                            id: entry
                            required property var modelData
                            notif: modelData
                            popup: false
                            property Region blur: Region { item: entry.background; radius: Theme.radius }
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
                            text: "No Notifications"
                            color: Theme.dim
                            font.pointSize: 10
                        }
                    }
                }
            }
        }
    }
}
