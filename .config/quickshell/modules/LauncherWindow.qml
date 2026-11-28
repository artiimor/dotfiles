// The launcher window (what used to be wofi). The logic of each mode
// is in services/Launcher.qml.
//
// Style: clean (search box on top, flat list, no
// effects), all square and borderless. In the theme menu each row has
// its color palette on the right (fonts, written in themselves) and
// in the backgrounds one, its thumbnail. In the mac profiles (Theme.mac) it looks like
// macshell: rounded corners, thin border, translucent blurred background
// and the selected row in blue.
//
// Keys: typing filters · ↑/↓ or Ctrl+K/J or Tab move · Enter select · Esc close
// Clicking outside also closes. With tabs (themes: Dark / Light / Font), Tab, Shift+Tab
// and ←/→ switch tab and ↑/↓ move. Each tab has its own search: when
// you come back to one, what you typed in it is still there. In the main menu's submenus,
// → enters the row if it opens another menu and ← goes back to the previous one (with tabs, from the
// first one). In menus without a search box, h j k l act as arrows. With a fixed tab
// (themes from the style menu) only the list is shown: no search box and no tabs.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: win

    screen: Theme.focusedScreen
    visible: Launcher.open

    // Apps, clipboard, emojis and power (Super+Escape) in the center; the
    // other menus, top right under the bar (as they were with wofi)
    anchors {
        top: !Launcher.centered
        right: !Launcher.centered
    }
    margins {
        top: TopBar.belowBar
        right: Theme.gap
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    implicitWidth: Launcher.width
    implicitHeight: box.implicitHeight
    color: "transparent"
    BackgroundEffect.blurRegion: Theme.mac ? blur : null
    Region { id: blur; item: box; radius: box.radius }

    HyprlandFocusGrab {
        windows: [win]
        active: win.visible
        onCleared: Launcher.close()
    }

    // Every time a mode opens or a dmenu question arrives (even if the
    // window was already open): empty search box, first row and focus on it
    Connections {
        target: Launcher
        function onShown() {
            win.queries = [];
            win.queryTab = Launcher.tab;
            search.text = "";
            list.currentIndex = 0;
            search.forceActiveFocus();
        }
        // When switching tab the typed text is saved and the new tab's is restored
        function onTabChanged() {
            win.queries[win.queryTab] = search.text;
            win.queryTab = Launcher.tab;
            search.text = win.queries[Launcher.tab] ?? "";
        }
    }

    // Search of each tab (index = tab) and the tab that
    // the current search box text belongs to
    property var queries: []
    property int queryTab: 0

    // ── Filtering ──────────────────────────────────────────
    // First whatever contains the text as is (the closer to the
    // start, the earlier), then whatever has the letters in order ("ffx" → Firefox)
    readonly property var filtered: {
        const q = search.text.toLowerCase().trim();
        const all = Launcher.tabs.length ? Launcher.items.filter(it => it.tab === Launcher.tab) : Launcher.items;
        if (!q || Launcher.password)
            return Launcher.password ? [] : all;
        const scored = [];
        for (const it of all) {
            const hay = [it.text, it.sub, it.keywords].filter(s => s).join(" ").toLowerCase();
            const i = hay.indexOf(q);
            let score = -1;
            if (i >= 0)
                score = 1000 - i;
            else {
                // Without spaces: "fira code" also finds "FiraCode"
                const letters = q.replace(/\s+/g, "");
                let j = 0;
                for (const c of hay) if (c === letters[j]) j++;
                if (j === letters.length)
                    score = 1;
            }
            if (score >= 0)
                scored.push({ it, score });
        }
        return scored.sort((a, b) => b.score - a.score).map(s => s.it);
    }
    // With the first row selected, or nothing searched, the current one (`cur`, the active theme)
    // if it is in the list. With callLater: otherwise the ListView, which hasn't
    // picked up the new list yet, resets it to the first row when it does
    onFilteredChanged: Qt.callLater(selectDefault)
    // (if there is no current one, Launcher.startIndex: when going back to a menu, the one you left from)
    function selectDefault() {
        const cur = filtered.findIndex(it => it.cur);
        list.currentIndex = search.text.trim() ? 0 : cur >= 0 ? cur : Launcher.startIndex;
    }

    function accept() {
        Launcher.choose(filtered[list.currentIndex] ?? null, search.text);
    }

    // Maximum list height depending on the mode
    readonly property int maxRows: Launcher.centered ? 8 : 6
    readonly property int rowHeight: 38

    Rectangle {
        id: box
        width: Launcher.width
        implicitHeight: column.implicitHeight + 28
        color: Theme.launcherBg
        radius: Theme.mac ? Theme.radius : 0
        border.width: Theme.mac ? 1 : 0
        border.color: Theme.border

        ColumnLayout {
            id: column
            x: 14
            y: 14
            width: parent.width - 28
            spacing: Launcher.noSearch ? 0 : 12

            // ── Search box: text only, no background or magnifier ──────
            // (the lock only appears when asking for a password)
            // Not shown in the power menu: height 0 and transparent, but it still
            // exists to receive keys (arrows, Enter, Esc)
            Item {
                Layout.fillWidth: true
                implicitHeight: Launcher.noSearch ? 0 : 36
                Layout.preferredHeight: implicitHeight
                Layout.maximumHeight: implicitHeight
                opacity: Launcher.noSearch ? 0 : 1

                Text {
                    id: searchIcon
                    visible: Launcher.password
                    width: visible ? implicitWidth : 0
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    color: Theme.mac ? Theme.accent : Theme.pink
                    font.family: Theme.font
                    font.pixelSize: 16
                }

                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: searchIcon.visible ? 12 : 0
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    selectionColor: Theme.accentDim
                    font.family: Theme.font
                    font.pixelSize: 15
                    echoMode: Launcher.password ? TextInput.Password : TextInput.Normal
                    readOnly: Launcher.noSearch
                    clip: true

                    // Sin cursor visible
                    cursorDelegate: Item {}

                    Text {
                        visible: !search.text
                        text: Launcher.tabPrompt || Launcher.prompt || I18n.tr("Search…")
                        color: Theme.muted
                        font: search.font
                    }

                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        const n = Launcher.fixedTab ? 0 : Launcher.tabs.length;
                        // Sin buscador, h j k l son ← ↓ ↑ →
                        const key = Launcher.noSearch && !ctrl
                            ? ({ [Qt.Key_H]: Qt.Key_Left, [Qt.Key_J]: Qt.Key_Down, [Qt.Key_K]: Qt.Key_Up, [Qt.Key_L]: Qt.Key_Right })[e.key] ?? e.key
                            : e.key;
                        // ← on the first tab (or without tabs) goes back to the previous menu
                        const back = key === Qt.Key_Left && Launcher.history.length > 0 && (!n || Launcher.tab === 0);
                        if (n && (key === Qt.Key_Tab || key === Qt.Key_Right))
                            Launcher.tab = (Launcher.tab + 1) % n;
                        else if (back)
                            Launcher.back();
                        else if (n && (key === Qt.Key_Backtab || key === Qt.Key_Left))
                            Launcher.tab = (Launcher.tab + n - 1) % n;
                        else if (key === Qt.Key_Right && Launcher.opensMenu(win.filtered[list.currentIndex]))
                            win.accept();
                        else if (key === Qt.Key_Escape)
                            Launcher.close();
                        else if (key === Qt.Key_Return || key === Qt.Key_Enter)
                            win.accept();
                        else if (key === Qt.Key_Down || key === Qt.Key_Tab || (ctrl && key === Qt.Key_J))
                            list.incrementCurrentIndex();
                        else if (key === Qt.Key_Up || key === Qt.Key_Backtab || (ctrl && key === Qt.Key_K))
                            list.decrementCurrentIndex();
                        else if (key === Qt.Key_PageDown)
                            list.currentIndex = Math.min(list.count - 1, list.currentIndex + win.maxRows);
                        else if (key === Qt.Key_PageUp)
                            list.currentIndex = Math.max(0, list.currentIndex - win.maxRows);
                        else
                            return;
                        e.accepted = true;
                    }
                }
            }

            // ── Tabs (only in the modes that have them) ─────
            // The selected one, bold with an accent line below; in mac, a
            // grey pill like macOS segmented controls
            RowLayout {
                visible: Launcher.tabs.length > 0 && !Launcher.fixedTab
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                spacing: 4

                Repeater {
                    model: Launcher.tabs

                    Rectangle {
                        id: tabItem
                        required property string modelData
                        required property int index
                        readonly property bool selected: Launcher.tab === index

                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: Theme.mac ? 8 : 0
                        color: selected && Theme.mac ? Theme.surface
                            : tabMouse.containsMouse ? Theme.withAlpha(Theme.launcherSel, 0.5) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: tabItem.modelData
                            color: tabItem.selected ? Theme.fg : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.bold: tabItem.selected
                        }

                        Rectangle {
                            visible: tabItem.selected && !Theme.mac
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            color: Theme.accent
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Launcher.tab = tabItem.index
                        }
                    }
                }
            }

            // ── Resultados ─────────────────────────────────────
            ListView {
                id: list
                Layout.fillWidth: true
                // Fixed height from the mode's items (unfiltered): doesn't shrink while typing.
                // With a fixed tab (no search box), that tab's items (at least one row,
                // so the "nothing here" fits)
                implicitHeight: Math.min(Launcher.fixedTab ? Math.max(1, win.filtered.length) : Launcher.items.length, win.maxRows) * win.rowHeight
                visible: Launcher.items.length > 0
                clip: true
                model: win.filtered
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: ListView.isCurrentItem

                    width: ListView.view.width
                    height: win.rowHeight

                    // Selected row: just a background block
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.mac ? 8 : 0
                        color: row.selected ? Theme.launcherSel : mouse.containsMouse ? Theme.withAlpha(Theme.launcherSel, 0.5) : "transparent"
                    }


                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        // Backgrounds: thumbnail of the background
                        Image {
                            visible: !!row.modelData.image
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 27
                            source: row.modelData.image ?? ""
                            sourceSize.width: 96
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        // Symbol (menus and emojis); apps have no icon
                        Text {
                            visible: !!row.modelData.glyph
                            Layout.preferredWidth: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: row.modelData.glyph ?? ""
                            color: row.selected ? (Theme.mac ? Theme.onAccent : Theme.pink) : Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 16
                        }

                        // Fonts (Font tab of themes): each one written in itself
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: row.modelData.text ?? ""
                            color: row.selected ? (Theme.mac ? Theme.onAccent : Theme.fg) : Theme.withAlpha(Theme.fg, Theme.mac ? 1 : 0.8)
                            font.family: row.modelData.font ?? Theme.font
                            font.pixelSize: 14
                            font.bold: row.selected && !Theme.mac
                        }

                        // Themes: their palette on their terminal background ("Aa" in the
                        // text color, the accent and 6 ANSI colors). Square like
                        // the rest of the launcher, or a pill with dots in mac
                        Rectangle {
                            id: chip
                            readonly property var pal: row.modelData.palette ?? null
                            visible: !!pal
                            Layout.preferredWidth: chipRow.implicitWidth + 16
                            Layout.preferredHeight: 22
                            radius: Theme.mac ? height / 2 : 0
                            color: pal ? pal.bg : "transparent"
                            border.width: 1
                            border.color: row.selected && Theme.mac ? Qt.rgba(1, 1, 1, 0.45)
                                : Theme.withAlpha(Theme.fg, Theme.mac ? 0.18 : 0.22)

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Aa"
                                    color: chip.pal ? chip.pal.fg : "transparent"
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                    font.bold: true
                                    rightPadding: 2
                                }

                                Repeater {
                                    model: chip.pal ? chip.pal.colors : []

                                    Rectangle {
                                        required property var modelData
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 10
                                        height: 10
                                        radius: Theme.mac ? 5 : 0
                                        color: modelData
                                    }
                                }
                            }
                        }

                        // Short description on the right (e.g. "Web browser")
                        Text {
                            visible: !!row.modelData.sub && Launcher.showSub
                            Layout.maximumWidth: Launcher.mode === "keys" ? 240 : 180
                            elide: Text.ElideRight
                            text: row.modelData.sub ?? ""
                            color: row.selected && Theme.mac ? Qt.rgba(1, 1, 1, 0.75) : Launcher.mode === "keys" ? Theme.accent : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            list.currentIndex = row.index;
                            win.accept();
                        }
                    }
                }
            }
        }

        // Above the list area, so the box height doesn't change
        Text {
            visible: list.visible && list.count === 0 && !Launcher.password && Launcher.mode !== "dmenu"
            x: column.x + list.x + (list.width - width) / 2
            y: column.y + list.y + (list.height - height) / 2
            text: "¯\\_(ツ)_/¯  " + I18n.tr("nothing here")
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
