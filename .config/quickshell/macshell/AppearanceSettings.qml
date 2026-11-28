pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// "Appearance" window in the style of macOS System Settings: mode (Mac or normal),
// color theme, wallpaper, font and increase contrast. Opened from
// the Control Center's "Appearance Settings…" and with `ipc call appearance open`.
// Data and changes go through the scripts in ~/.config/themes.
FloatingWindow {
    id: win
    title: "Appearance" // untranslated: a rule in hypr/config/windowrules.lua matches it
    visible: false
    color: Theme.window
    implicitWidth: 720
    implicitHeight: 560
    minimumSize: Qt.size(520, 420)

    readonly property string themesDir: Quickshell.env("HOME") + "/.config/themes"

    // If it's already open (maybe on another workspace) it is recreated so it shows up where you are
    function show() {
        if (visible) { visible = false; Qt.callLater(() => { win.visible = true; }); }
        else visible = true;
        syncFilter = true;
        refresh();
    }
    onClosed: visible = false

    // ── data from the scripts ──
    property var profiles: []     // [{ key, name, cur }]
    property var themes: []       // [{ dir, name, cur, light, bg, fg, colors }]
    property var backgrounds: []  // [{ name, path, cur }]
    property var fonts: []        // [{ font, cur }]
    property bool showLight: false
    property bool syncFilter: false   // on open, the filter goes to the current theme's lightness
    property bool fontsOpen: false
    readonly property string curFont: (fonts.find(f => f.cur) ?? { font: "" }).font

    function refresh() {
        profileProc.running = true;
        themeProc.running = true;
        bgProc.running = true;
        fontProc.running = true;
    }
    function lines(text) { return text.split("\n").filter(l => l); }

    // config-set restarts macshell when switching to Normal Mode: setsid so it doesn't die with
    // it. Everything else (including switching between Mac light and dark) doesn't close it: everything is re-read
    // without touching the Dark/Light filter or the scroll position. With `list` and `key` (e.g.
    // "themes", "dir") the selected mark moves to that row at once, without waiting for the re-read
    // The lists are re-read as soon as the script exits (light/dark themes swap the backgrounds,
    // e.g. the day/night Pepes). config-set may restart macshell, so it stays detached + timer.
    function run(script, arg, list, key) {
        if (list) win[list] = win[list].map(x => Object.assign({}, x, { cur: x[key] === arg }));
        if (script === "config-set") {
            Quickshell.execDetached(["setsid", "-f", themesDir + "/" + script, arg]);
            refreshSoon.restart();
        } else if (runProc.running) {
            // queued in click order, only the last click of each script
            const cmd = [themesDir + "/" + script, arg];
            win.pendingRuns = win.pendingRuns.filter(c => c[0] !== cmd[0]).concat([cmd]);
        } else {
            runProc.command = [themesDir + "/" + script, arg];
            runProc.running = true;
        }
    }
    property var pendingRuns: []
    Process {
        id: runProc
        onExited: {
            if (win.pendingRuns.length) {
                command = win.pendingRuns[0];
                win.pendingRuns = win.pendingRuns.slice(1);
                running = true;
            } else win.refresh();
        }
    }
    Timer { id: refreshSoon; interval: 2000; onTriggered: win.refresh() }

    // `config-set --list`: "<profile>\t<name>\t<1 if current>"
    Process {
        id: profileProc
        command: [win.themesDir + "/config-set", "--list"]
        stdout: StdioCollector {
            onStreamFinished: win.profiles = win.lines(text).map(l => {
                const f = l.split("\t");
                return { key: f[0], name: f[1], cur: f[2] === "1" };
            })
        }
    }
    // `theme-set --list`: one JSON per line
    Process {
        id: themeProc
        command: [win.themesDir + "/theme-set", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.themes = win.lines(text).map(l => JSON.parse(l));
                const cur = win.themes.find(t => t.cur);
                if (win.syncFilter && cur) win.showLight = cur.light;
                win.syncFilter = false;
            }
        }
    }
    // `background-set`: "<background>\t<path>\t<1 if current>"
    Process {
        id: bgProc
        command: [win.themesDir + "/background-set"]
        stdout: StdioCollector {
            onStreamFinished: win.backgrounds = win.lines(text).map(l => {
                const f = l.split("\t");
                return { name: f[0], path: f[1], cur: f[2] === "1" };
            })
        }
    }
    // `background-set --add`: when the picker closes, re-read (the new background shows up selected)
    Process {
        id: addProc
        command: [win.themesDir + "/background-set", "--add"]
        onExited: bgProc.running = true
    }
    // `font-set --list`: one JSON { font, cur } per line
    Process {
        id: fontProc
        command: [win.themesDir + "/font-set", "--list"]
        stdout: StdioCollector { onStreamFinished: win.fonts = win.lines(text).map(l => JSON.parse(l)) }
    }

    // ── piezas ──
    component SectionTitle: SectionLabel {
        Layout.topMargin: 14
        Layout.leftMargin: 4
        font.pointSize: 9
    }

    // rounded box grouping rows, like in System Settings
    component Group: Tile { Layout.fillWidth: true; padding: 0; spacing: 0 }

    // row with the name on the left and the children on the right
    component LabelRow: RowLayout {
        property string label: ""
        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 10
        Text { Layout.fillWidth: true; text: parent.label; color: Theme.text; font.pointSize: 10 }
    }

    // macOS segmented control: [{ key, label }], highlights the current one
    component Segmented: Rectangle {
        id: seg
        property var options: []
        property string current: ""
        signal picked(string key)
        implicitWidth: segRow.implicitWidth + 4
        implicitHeight: 26
        radius: 7
        color: Theme.tint(0.08)
        border.width: Theme.outlineWidth
        border.color: Theme.separator
        Row {
            id: segRow
            x: 2; y: 2
            Repeater {
                model: seg.options
                delegate: Rectangle {
                    id: opt
                    required property var modelData
                    readonly property bool sel: modelData.key === seg.current
                    implicitWidth: optText.implicitWidth + 24
                    implicitHeight: 22
                    radius: 5
                    color: sel ? Theme.tint(0.22) : "transparent"
                    Text {
                        id: optText
                        anchors.centerIn: parent
                        text: opt.modelData.label
                        color: Theme.text
                        font.pointSize: 9.5
                        font.weight: opt.sel ? Font.DemiBold : Font.Normal
                    }
                    MouseArea { anchors.fill: parent; onClicked: if (!opt.sel) seg.picked(opt.modelData.key) }
                }
            }
        }
    }

    // grid that splits the width into columns of at least minWidth
    component CardGrid: Flow {
        property real minWidth: 140
        readonly property int cols: Math.max(1, Math.floor((width + spacing) / (minWidth + spacing)))
        readonly property real cellWidth: (width - (cols - 1) * spacing) / cols
        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 12
    }

    // ── contenido ──
    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            x: 20; y: 16
            width: parent.width - 40
            spacing: 6

            Text {
                text: I18n.tr("Appearance")
                color: Theme.text
                font.pointSize: 15
                font.weight: Font.Bold
                Layout.bottomMargin: 4
            }

            // ── mode and font ──
            Group {
                LabelRow {
                    label: I18n.tr("Mode")
                    Segmented {
                        options: win.profiles.map(p => ({ key: p.key, label: p.name }))
                        current: (win.profiles.find(p => p.cur) ?? { key: "" }).key
                        onPicked: key => win.run("config-set", key)
                    }
                }
                Divider { Layout.leftMargin: 12; Layout.rightMargin: 12 }
                // font drop-down menu
                LabelRow {
                    label: I18n.tr("Font")
                    PillButton {
                        text: win.curFont + "  ▾"
                        onTapped: win.fontsOpen = !win.fontsOpen
                    }
                }
                ListView {
                    visible: win.fontsOpen
                    Layout.fillWidth: true
                    Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.bottomMargin: 8
                    implicitHeight: Math.min(contentHeight, 26 * 8)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.fonts
                    // when it opens, scroll the current font into view
                    onVisibleChanged: if (visible) positionViewAtIndex(win.fonts.findIndex(f => f.cur), ListView.Contain)
                    delegate: MenuRow {
                        required property var modelData
                        width: ListView.view.width
                        text: modelData.font
                        checkable: true
                        checked: modelData.cur
                        onTriggered: { win.fontsOpen = false; win.run("font-set", modelData.font, "fonts", "font"); }
                    }
                }
            }

            // ── color theme ──
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { Layout.fillWidth: true; text: I18n.tr("Theme") }
                Segmented {
                    Layout.topMargin: 14
                    options: [{ key: "dark", label: I18n.tr("Dark") }, { key: "light", label: I18n.tr("Light") }]
                    current: win.showLight ? "light" : "dark"
                    onPicked: key => win.showLight = key === "light"
                }
            }
            Group {
                CardGrid {
                    id: themeGrid
                    Repeater {
                        model: win.themes.filter(t => t.light === win.showLight)
                        delegate: Column {
                            id: card
                            required property var modelData
                            width: themeGrid.cellWidth
                            spacing: 6
                            // preview: background, "Aa" in the text color and the palette
                            Rectangle {
                                width: parent.width
                                height: 64
                                radius: 8
                                color: card.modelData.bg
                                border.width: card.modelData.cur ? 2 : 1
                                border.color: card.modelData.cur ? Theme.accent : Theme.tint(0.12)
                                Text {
                                    x: 10; y: 6
                                    text: "Aa"
                                    color: card.modelData.fg
                                    font.pointSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Row {
                                    x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 9
                                    spacing: 4
                                    Repeater {
                                        model: card.modelData.colors
                                        delegate: Rectangle {
                                            required property string modelData
                                            width: 10; height: 10; radius: 5
                                            color: modelData
                                        }
                                    }
                                }
                                Rectangle {
                                    visible: card.modelData.cur
                                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
                                    width: 18; height: 18; radius: 9
                                    color: Theme.accent
                                    Glyph { anchors.centerIn: parent; width: 11; height: 11; name: "check"; color: "white" }
                                }
                                MouseArea { anchors.fill: parent; onClicked: if (!card.modelData.cur) win.run("theme-set", card.modelData.dir, "themes", "dir") }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: card.modelData.name
                                color: card.modelData.cur ? Theme.text : Theme.dim
                                font.pointSize: 9
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // ── wallpaper (the current theme's) ──
            SectionTitle { text: I18n.tr("Wallpaper") }
            Group {
                CardGrid {
                    id: bgGrid
                    minWidth: 120
                    Repeater {
                        model: win.backgrounds
                        delegate: Rectangle {
                            id: bg
                            required property var modelData
                            width: bgGrid.cellWidth
                            height: width * 0.625
                            radius: 8
                            color: Theme.tint(0.08)
                            border.width: 2
                            border.color: modelData.cur ? Theme.accent : "transparent"
                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: "file://" + bg.modelData.path
                                sourceSize.width: 240
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            MouseArea { anchors.fill: parent; onClicked: if (!bg.modelData.cur) win.run("background-set", bg.modelData.name, "backgrounds", "name") }
                        }
                    }
                    // "Add…": image picker (background-set --add copies them to the theme and applies the last one)
                    Rectangle {
                        width: bgGrid.cellWidth
                        height: width * 0.625
                        radius: 8
                        color: addMouse.containsMouse ? Theme.buttonHover : Theme.button
                        Column {
                            anchors.centerIn: parent
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "+"; color: Theme.dim; font.pointSize: 18 }
                            Text { text: I18n.tr("Add…"); color: Theme.dim; font.pointSize: 9 }
                        }
                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: addProc.running = true
                        }
                    }
                }
            }

            // ── accesibilidad ──
            SectionTitle { text: I18n.tr("Accessibility") }
            Group {
                LabelRow {
                    label: I18n.tr("Increase Contrast")
                    Switch { on: Theme.contrast; onToggled: Sys.toggleContrast() }
                }
            }
        }
    }
}
