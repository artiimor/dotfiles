pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Buscador estilo Spotlight de macOS (Cmd/Super + Espacio).
// Apps, calculadora (qalc) y archivos de $HOME (fd).
PanelWindow {
    id: win

    property bool open: false
    function toggle() { open ? close() : show(); }
    function show() { field.text = ""; sel = 0; open = true; field.forceActiveFocus(); }
    function close() { open = false; }
    function setQuery(q) { field.text = q; }

    visible: open || card.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "macshell-spotlight"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    BackgroundEffect.blurRegion: Region { item: card; radius: 22 }

    // ── búsqueda ──
    readonly property string query: field.text.trim()
    property int sel: 0
    property var fileHits: []
    property string calc: ""

    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    function score(e, q) {
        const n = e.name.toLowerCase();
        if (n === q) return 100;
        if (n.startsWith(q)) return 90 - n.length * 0.1;
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 70;
        // iniciales: "vsc" → Visual Studio Code
        const ini = n.split(/[\s\-_.]+/).map(w => w[0]).join("");
        if (ini.startsWith(q)) return 60;
        if (n.includes(q)) return 50;
        const extra = ((e.genericName || "") + " " + e.keywords.join(" ") + " " + (e.comment || "")).toLowerCase();
        if (extra.includes(q)) return 30;
        return 0;
    }

    readonly property var appHits: {
        const q = query.toLowerCase();
        if (!q) return [];
        return apps.map(e => ({ e, s: score(e, q) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name))
            .slice(0, 8)
            .map(x => x.e);
    }

    // Lista plana de filas: { kind: "header"|"top"|"app"|"calc"|"file", ... }
    readonly property var rows: {
        const q = query;
        if (!q) return [];
        const out = [];
        const add = r => out.push(r);
        if (calc !== "")
            add({ kind: "top", type: "calc", title: calc, sub: q + " =", icon: "accessories-calculator" });
        const a = appHits;
        if (a.length) {
            if (calc === "")
                add({ kind: "top", type: "app", entry: a[0], title: a[0].name, sub: "Application", icon: a[0].icon });
            const rest = calc === "" ? a.slice(1) : a;
            if (rest.length) {
                add({ kind: "header", title: "Applications" });
                rest.forEach(e => add({ kind: "item", type: "app", entry: e, title: e.name, sub: (e.genericName && e.genericName !== e.name) ? e.genericName : "", icon: e.icon }));
            }
        }
        if (fileHits.length) {
            const first = out.length === 0;
            fileHits.forEach((f, i) => {
                const r = { kind: "item", type: "file", path: f.path, title: f.name, sub: f.dir, icon: f.icon };
                if (first && i === 0) { r.kind = "top"; add(r); add({ kind: "header", title: "Documents" }); }
                else { if (i === 0) add({ kind: "header", title: "Documents" }); add(r); }
            });
        }
        // si la sección de documentos quedó vacía tras el primero, quita su cabecera
        return out.filter((r, i) => !(r.kind === "header" && (i === out.length - 1 || out[i + 1].kind === "header")));
    }
    readonly property var selectable: rows.map((r, i) => r.kind === "header" ? -1 : i).filter(i => i >= 0)

    onQueryChanged: {
        sel = 0;
        calc = "";
        fileHits = [];
        fileTimer.restart();
        if (/\d/.test(query) && /[-+*/^%()]|sqrt|sin|cos|tan|log|pi|to |in /.test(query)) calcTimer.restart();
    }
    onRowsChanged: if (sel >= selectable.length) sel = Math.max(0, selectable.length - 1)

    function move(d) {
        if (!selectable.length) return;
        sel = (sel + d + selectable.length) % selectable.length;
        list.positionViewAtIndex(selectable[sel], ListView.Contain);
    }

    function activate(r) {
        if (!r) return;
        close();
        switch (r.type) {
        case "app": r.entry.execute(); break;
        case "file": Quickshell.execDetached(["xdg-open", r.path]); break;
        case "calc": Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", r.title]); break;
        }
    }

    // ── calculadora ──
    Timer { id: calcTimer; interval: 120; onTriggered: { calcProc.running = false; calcProc.q = win.query; calcProc.running = true; } }
    Process {
        id: calcProc
        property string q: ""
        command: ["qalc", "-t", "-set", "decimal comma off", q]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (calcProc.q === win.query && t && !/error|warning/i.test(t) && t !== calcProc.q)
                    win.calc = t;
            }
        }
    }

    // ── archivos ──
    Timer {
        id: fileTimer; interval: 180
        onTriggered: {
            fileProc.running = false;
            if (win.query.length < 2) return;
            fileProc.q = win.query;
            fileProc.running = true;
        }
    }
    Process {
        id: fileProc
        property string q: ""
        command: ["fd", "-i", "--max-results", "6", "--max-depth", "6", "-E", "node_modules", "-E", ".cache",
                  "--fixed-strings", "--", q, Quickshell.env("HOME")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (fileProc.q !== win.query) return;
                const home = Quickshell.env("HOME");
                win.fileHits = text.split("\n").filter(l => l).map(p => {
                    const isDir = p.endsWith("/");
                    const clean = isDir ? p.slice(0, -1) : p;
                    const i = clean.lastIndexOf("/");
                    return { path: clean, name: clean.slice(i + 1), dir: clean.slice(0, i).replace(home, "~") || "/",
                             icon: isDir ? "folder" : win.iconFor(clean) };
                });
            }
        }
    }
    function iconFor(p) {
        const ext = p.slice(p.lastIndexOf(".") + 1).toLowerCase();
        return extIcons[ext] ?? "text-x-generic";
    }
    readonly property var extIcons: ({ pdf: "application-pdf", png: "image-x-generic", jpg: "image-x-generic", jpeg: "image-x-generic",
                    svg: "image-svg+xml", webp: "image-x-generic", gif: "image-x-generic", mp4: "video-x-generic",
                    mkv: "video-x-generic", mp3: "audio-x-generic", flac: "audio-x-generic", zip: "application-zip",
                    gz: "application-x-compressed-tar", tar: "application-x-tar", sh: "application-x-shellscript",
                    py: "text-x-python", js: "text-x-javascript", qml: "text-x-qml", html: "text-html",
                    md: "text-markdown", txt: "text-plain", doc: "x-office-document", docx: "x-office-document",
                    odt: "x-office-document", xls: "x-office-spreadsheet", xlsx: "x-office-spreadsheet",
                    ods: "x-office-spreadsheet", ppt: "x-office-presentation", pptx: "x-office-presentation" })

    // ── interfaz ──
    MouseArea { anchors.fill: parent; enabled: win.open; onClicked: win.close() }

    Rectangle {
        id: card
        width: 680
        x: (parent.width - width) / 2
        y: parent.height * 0.22
        height: 56 + (win.rows.length ? Math.min(list.contentHeight, 440) + 13 : 0)
        radius: 22
        color: Theme.overlay
        border.color: Theme.border
        clip: true
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // no cerrar al hacer clic dentro

        Item {
            id: header
            width: parent.width
            height: 56

            Glyph {
                x: 20; anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22
                name: "search"
                color: Theme.dim
            }
            TextInput {
                id: field
                anchors { left: parent.left; leftMargin: 54; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.accent
                font.pointSize: 17
                font.weight: Font.Light
                clip: true
                focus: true
                Text {
                    visible: !field.text
                    text: "Search"
                    color: Theme.dim
                    font: field.font
                }
                Keys.onPressed: ev => {
                    const ctrl = ev.modifiers & Qt.ControlModifier;
                    if (ev.key === Qt.Key_Escape) { win.close(); ev.accepted = true; }
                    else if (ev.key === Qt.Key_Down || ev.key === Qt.Key_Tab || (ctrl && ev.key === Qt.Key_N)) { win.move(1); ev.accepted = true; }
                    else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab || (ctrl && ev.key === Qt.Key_P)) { win.move(-1); ev.accepted = true; }
                    else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                        win.activate(win.rows[win.selectable[win.sel]]); ev.accepted = true;
                    }
                }
            }
        }

        Rectangle {
            visible: win.rows.length > 0
            y: 56; width: parent.width; height: 1
            color: Theme.border
        }

        ListView {
            id: list
            y: 63
            x: 8
            width: parent.width - 16
            height: Math.min(contentHeight, 440)
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: win.rows

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool isHeader: modelData.kind === "header"
                readonly property bool isTop: modelData.kind === "top"
                readonly property bool current: win.selectable[win.sel] === index
                width: list.width
                height: isHeader ? 26 : isTop ? 54 : 34

                Text {
                    visible: row.isHeader
                    x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                    text: row.modelData.title
                    color: Theme.dim
                    font.pointSize: 8.5
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: !row.isHeader
                    anchors.fill: parent
                    radius: 10
                    color: row.current ? Theme.accent : hover.hovered ? Theme.button : "transparent"
                }
                HoverHandler { id: hover; enabled: !row.isHeader }
                TapHandler {
                    enabled: !row.isHeader
                    onTapped: win.activate(row.modelData)
                }

                RowLayout {
                    visible: !row.isHeader
                    anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                    spacing: 10
                    Image {
                        Layout.preferredWidth: row.isTop ? 38 : 22
                        Layout.preferredHeight: row.isTop ? 38 : 22
                        sourceSize: Qt.size(64, 64)
                        source: Quickshell.iconPath(row.modelData.icon || "", "application-x-executable")
                        smooth: true
                        asynchronous: false
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            color: row.current ? "white" : Theme.text
                            font.pointSize: row.isTop ? 13 : 10.5
                            font.weight: row.isTop ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: row.isTop && text !== ""
                            Layout.fillWidth: true
                            text: row.modelData.sub ?? ""
                            color: row.current ? Qt.rgba(1, 1, 1, 0.75) : Theme.dim
                            font.pointSize: 9
                            elide: Text.ElideMiddle
                        }
                    }
                    Text {
                        visible: !row.isTop && text !== ""
                        Layout.maximumWidth: 260
                        text: row.modelData.sub ?? ""
                        color: row.current ? Qt.rgba(1, 1, 1, 0.75) : Theme.dim
                        font.pointSize: 9
                        elide: Text.ElideMiddle
                    }
                    Text {
                        visible: row.current
                        text: row.modelData.type === "calc" ? "↵ copy" : "↵"
                        color: Qt.rgba(1, 1, 1, 0.75)
                        font.pointSize: 9
                    }
                }
            }
        }
    }
}
