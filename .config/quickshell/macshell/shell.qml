pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    // ── estado compartido ──
    property var popups: []          // notificaciones que se ven ahora como banners
    property bool centerOpen: false
    property bool dnd: false
    property string popupKind: ""    // "", "cc", "wifi", "battery", "clip", "sound", "display", "system", "tray"
    property var popupItem: null     // SystemTrayItem para "tray"
    property real popupRight: 6      // distancia de popWin al borde derecho de la pantalla
    readonly property int popupMargin: 8   // margen transparente de popWin alrededor de la tarjeta

    onCenterOpenChanged: if (centerOpen) popups = []

    function hidePopup(n) { popups = popups.filter(p => p && p !== n); }

    // sin botón (desde IPC) se pega a la derecha de la pantalla
    function openPopup(kind, button, item) {
        centerOpen = false;
        popupItem = item ?? null;
        // el borde derecho de la tarjeta queda a popupRight + popupMargin de la pantalla:
        // así sobresale 6 px a la derecha del botón
        popupRight = button ? Math.max(6, button.rightDistance() - popupMargin - 6) : 6;
        popupKind = kind;
    }
    function togglePopup(kind, button, item) {
        if (popupKind === kind && popupItem === (item ?? null)) closeAll();
        else openPopup(kind, button, item);
    }
    function closeAll() { popupKind = ""; popupItem = null; centerOpen = false; }
    function toggleCenter() { popupKind = ""; popupItem = null; centerOpen = !centerOpen; }
    function clearNotifications() { server.trackedNotifications.values.slice().forEach(n => n.dismiss()); }
    // memoria y temperatura más a menudo mientras se ven
    Binding { target: Sys; property: "statsFast"; value: root.popupKind === "system" }

    // ───────────── notificaciones ─────────────
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
        function toggle(): void { root.toggleCenter(); }
        function open(): void { root.centerOpen = true; }
        function close(): void { root.centerOpen = false; }
        function clear(): void { root.clearNotifications(); }
    }

    IpcHandler {
        target: "bar"
        // qs -p ~/.config/quickshell/macshell ipc call bar open cc|wifi|battery|clip|sound|display|system
        // ("tray" necesita un SystemTrayItem, así que no se acepta)
        function open(kind: string): void {
            if (["cc", "wifi", "battery", "clip", "sound", "display", "system"].includes(kind)) root.openPopup(kind);
        }
        function close(): void { root.closeAll(); }
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

    // ventana de Red (se abre poco): se construye la primera vez
    LazyLoader { id: netLoader; NetworkSettings {} }
    function openNetwork() { netLoader.active = true; netLoader.item.show(); }

    // qs -p ~/.config/quickshell/macshell ipc call appearance open (Super+M → Estilo)
    IpcHandler {
        target: "appearance"
        function open(): void { root.openAppearance(); }
        function close(): void { if (appearanceLoader.item) appearanceLoader.item.visible = false; }
    }

    // ventana de Apariencia, igual que la de Red
    LazyLoader { id: appearanceLoader; AppearanceSettings {} }
    function openAppearance() { closeAll(); appearanceLoader.active = true; appearanceLoader.item.show(); }

    // ───────────── barra superior ─────────────
    PanelWindow {
        id: bar
        anchors { top: true; right: true; left: true }
        exclusionMode: ExclusionMode.Auto
        // capa Top para que las ventanas a pantalla completa la tapen
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "macshell-bar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        implicitHeight: 26
        implicitWidth: barRow.implicitWidth + 16

        // ── fondo del panel + mitad izquierda ──
        BackgroundEffect.blurRegion: barBlur
        Region { id: barBlur; item: barBg }
        Rectangle {
            id: barBg
            anchors.fill: parent
            color: Theme.panel   // panel translúcido de Sur-Oscuro (claro en mac-light)
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

            // iconos de bandeja de las apps (StatusNotifierItems)
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

            // Ahora suena (MPRIS): solo con reproductor. Muestra lo que hará el clic
            // (como la barra normal). Clic: pausa · Rueda: canción siguiente / anterior
            BarButton {
                visible: Sys.player !== null
                scrollable: true
                Row {
                    spacing: 6
                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11; height: 11
                        name: Sys.player && Sys.player.isPlaying ? "pause" : "play"
                        color: Sys.player && Sys.player.isPlaying ? Theme.text : Theme.dim
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 180)
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: Sys.player ? [Sys.player.trackTitle, Sys.player.trackArtist].filter(t => t).join(" – ") || Sys.player.identity : ""
                        color: Sys.player && Sys.player.isPlaying ? Theme.text : Theme.dim
                        font.pointSize: 9.5
                    }
                }
                onClicked: m => {
                    if (m.button !== Qt.LeftButton) return;
                    root.closeAll();
                    Sys.player.togglePlaying();
                }
                onScrolled: steps => steps > 0 ? Sys.player.previous() : Sys.player.next()
            }

            // Cafeína: solo se ve mientras está activa (como Amphetamine); se activa
            // desde el Control Center. Clic: desactivar
            BarButton {
                visible: Sys.caffeine
                Glyph { width: 15; height: 15; name: "cup" }
                onClicked: Sys.toggleCaffeine()
            }

            // Sistema: memoria, temperatura, perfil de energía y apagado (el cajón de la
            // barra normal). El icono se pone rojo con la CPU a temperatura crítica
            BarButton {
                id: sysBtn
                active: root.popupKind === "system"
                Glyph {
                    width: 16; height: 16
                    name: "gauge"
                    color: Sys.temp >= Sys.tempCritical ? Theme.red : Theme.text
                }
                onClicked: root.togglePopup("system", sysBtn)
            }

            BarButton {
                id: clipBtn
                active: root.popupKind === "clip"
                ClipIcon {}
                onClicked: root.togglePopup("clip", clipBtn)
            }

            // Bluetooth · Clic: bzmenu con el lanzador de la config raíz (como la barra
            // normal) · Clic derecho: encender / apagar
            BarButton {
                visible: Sys.bt !== null
                Glyph {
                    width: 16; height: 16
                    name: Sys.btConnected.length > 0 ? "bluetooth-connected" : "bluetooth"
                    off: !Sys.btOn
                }
                onClicked: m => {
                    root.closeAll();
                    if (m.button === Qt.RightButton) Sys.bt.enabled = !Sys.bt.enabled;
                    else Quickshell.execDetached(["bzmenu", "-l", "custom", "--launcher-command",
                        `${Quickshell.shellDir}/../scripts/dmenu-qs -p '{hint}'`]);
                }
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

            // Brillo: solo con panel retroiluminado · Rueda: ±5 % · Clic: menú de
            // Pantalla (brillo y Night Shift)
            BarButton {
                id: brightBtn
                visible: Sys.hasBacklight
                active: root.popupKind === "display"
                scrollable: true
                Glyph { width: 16; height: 16; name: "sun" }
                onClicked: { Sys.refreshBrightness(); Sys.refreshNight(); root.togglePopup("display", brightBtn); }
                onScrolled: steps => Sys.stepBrightness(steps)
            }

            // Sonido · Clic: menú de sonido · Clic derecho: silenciar · Rueda: ±5 %
            BarButton {
                id: soundBtn
                active: root.popupKind === "sound"
                scrollable: true
                Glyph {
                    width: 17; height: 17
                    name: "speaker"
                    level: Sys.volume
                    off: Sys.muted
                }
                onClicked: m => m.button === Qt.RightButton ? Sys.toggleMute() : root.togglePopup("sound", soundBtn)
                onScrolled: steps => Sys.stepVolume(0.05 * steps)
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
                onClicked: { Sys.refreshBrightness(); Sys.refreshNight(); Sys.syncCaffeine(); root.togglePopup("cc", ccBtn); }
            }

            BarButton {
                Glyph { width: 15; height: 15; name: "search" }
                onClicked: { root.closeAll(); spotlight.toggle(); }
            }

            BarButton {
                active: root.centerOpen
                Text {
                    text: Theme.locale.toString(Theme.now, I18n.dateFormat(true, true) + "   HH:mm")
                    color: Theme.text
                    font.pointSize: 9.5
                }
                onClicked: root.toggleCenter()
            }
        }
    }

    // ───────────── captura de clics fuera ─────────────
    PanelWindow {
        visible: root.centerOpen || root.popupKind !== ""
        anchors { top: true; bottom: true; left: true; right: true }
        // deja la barra al descubierto para que sus botones sigan funcionando
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "macshell-catcher"
        color: "transparent"
        MouseArea { anchors.fill: parent; onClicked: root.closeAll() }
    }

    // ───────────── popups de la barra ─────────────
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
        implicitWidth: popSurface.width + 2 * root.popupMargin
        implicitHeight: popSurface.height + 2 * root.popupMargin

        BackgroundEffect.blurRegion: Region { item: popSurface; radius: Theme.radius }

        Rectangle {
            id: popSurface
            x: root.popupMargin; y: root.popupMargin
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
                readonly property var widths: ({ cc: 330, wifi: 300, battery: 290, clip: 300, sound: 270, display: 250, system: 250, tray: 260 })
                width: widths[root.popupKind] ?? 280
                height: item ? item.implicitHeight : 0
                sourceComponent: {
                    switch (root.popupKind) {
                    case "cc": return ccComp;
                    case "wifi": return wifiComp;
                    case "battery": return batComp;
                    case "tray": return trayComp;
                    case "clip": return clipComp;
                    case "sound": return soundComp;
                    case "display": return displayComp;
                    case "system": return systemComp;
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
                onOpenAppearance: root.openAppearance()
            }
        }
        Component { id: wifiComp; WifiPanel { onDone: root.closeAll(); onOpenSettings: root.openNetwork() } }
        Component { id: batComp; BatteryPanel {} }
        Component { id: clipComp; ClipboardPanel { onDone: root.closeAll() } }
        Component { id: soundComp; SoundPanel {} }
        Component { id: displayComp; DisplayPanel {} }
        Component {
            id: systemComp
            SystemPanel {
                // el menú de perfiles es el lanzador de la config raíz (sale junto a la barra)
                onOpenProfiles: { root.closeAll(); Quickshell.execDetached(["qs", "ipc", "call", "launcher", "profiles"]); }
                onOpenPower: { root.closeAll(); spotlight.close(); powerMenu.show(); }
            }
        }
        Component { id: trayComp; TrayMenu { item: root.popupItem; onDone: root.closeAll() } }
    }

    // ───────────── banners (arriba a la derecha) ─────────────
    PanelWindow {
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
        BackgroundEffect.blurRegion: Region { regions: Theme.cardBlurs(bannerList) }

        ListView {
            id: bannerList
            x: 8; y: 8
            width: Theme.width
            height: contentHeight
            interactive: false
            spacing: 8
            model: ScriptModel { values: root.popups.filter(p => p) }

            delegate: Card {
                required property var modelData
                notif: modelData
                popup: true
                onTimedOut: root.hidePopup(modelData)
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

    // ───────────── centro de notificaciones ─────────────
    NotificationCenter {
        open: root.centerOpen
        notifications: server.trackedNotifications.values
        onCloseRequested: root.centerOpen = false
        onClearRequested: root.clearNotifications()
    }
}
