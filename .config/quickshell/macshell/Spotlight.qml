pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Buscador estilo Spotlight de macOS (Cmd/Super + Espacio).
// Apps, calculadora (qalc) y archivos de $HOME (fd).
OverlayWindow {
    id: win

    function setQuery(q) { field.text = q; }
    onShown: { field.text = ""; sel = 0; field.forceActiveFocus(); }

    WlrLayershell.namespace: "macshell-spotlight"

    card.width: 680
    card.y: height * 0.22
    card.height: 56 + (rows.length ? Math.min(list.contentHeight, 440) + 13 : 0)
    card.color: Theme.overlay
    card.clip: true
    Behavior on card.height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    // ── búsqueda ──
    readonly property string query: field.text.trim()
    property int sel: 0
    property var fileHits: []
    property string calc: ""
    property string calcQuery: ""   // la cuenta de `calc` (puede ir por detrás de query hasta que responde qalc)

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

    // Lista plana de filas: { kind: "header"|"top"|"item", type: "app"|"calc"|"file", ... }.
    // La primera fila es "top": la cuenta si la hay; si no, el primer resultado de la primera sección.
    readonly property var rows: {
        const q = query;
        if (!q) return [];
        const sections = [
            ["Applications", appHits.map(e => ({ kind: "item", type: "app", entry: e, title: e.name,
                sub: (e.genericName && e.genericName !== e.name) ? e.genericName : "", icon: e.icon }))],
            ["Documents", fileHits.map(f => ({ kind: "item", type: "file", path: f.path, title: f.name, sub: f.dir, icon: f.icon }))]
        ];
        let top = calc !== "" ? { type: "calc", title: calc, sub: calcQuery + " =", icon: "accessories-calculator" } : null;
        const out = [];
        for (const [title, items] of sections) {
            if (!top && items.length) {
                top = items.shift();
                if (top.type === "app") top.sub = "Application";
            }
            if (items.length) out.push({ kind: "header", title }, ...items);
        }
        if (top) out.unshift(Object.assign(top, { kind: "top" }));
        return out;
    }
    readonly property var selectable: rows.map((r, i) => r.kind === "header" ? -1 : i).filter(i => i >= 0)

    onQueryChanged: {
        sel = 0;
        // los resultados viejos se quedan hasta que llegan los nuevos (así la tarjeta no parpadea);
        // solo se vacían cuando ya no aplican
        if (query.length < 2) fileHits = [];
        fileTimer.restart();
        if (/\d/.test(query) && /[-+*/^%()]|sqrt|sin|cos|tan|log|pi|to |in /.test(query)) calcTimer.restart();
        else calc = "";
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
                // salida vacía: proceso cortado por una consulta más nueva
                const t = text.trim();
                if (calcProc.q === win.query && t) {
                    win.calc = !/error|warning/i.test(t) && t !== calcProc.q ? t : "";
                    win.calcQuery = calcProc.q;
                }
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
        stdout: StdioCollector { id: fileOut }
        // en onExited y no en onStreamFinished: así se ignora un fd cortado (código != 0),
        // que si no vaciaría la lista
        onExited: code => {
            if (code !== 0 || fileProc.q !== win.query) return;
            const home = Quickshell.env("HOME");
            win.fileHits = fileOut.text.split("\n").filter(l => l).map(p => {
                const isDir = p.endsWith("/");
                const clean = isDir ? p.slice(0, -1) : p;
                const i = clean.lastIndexOf("/");
                return { path: clean, name: clean.slice(i + 1), dir: clean.slice(0, i).replace(home, "~") || "/",
                         icon: isDir ? "folder" : win.iconFor(clean) };
            });
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
            readonly property color softWhite: Qt.rgba(1, 1, 1, 0.75)   // texto secundario sobre la selección
            width: list.width
            height: isHeader ? 26 : isTop ? 54 : 34

            SectionLabel {
                visible: row.isHeader
                x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                text: row.modelData.title
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
                        color: row.current ? row.softWhite : Theme.dim
                        font.pointSize: 9
                        elide: Text.ElideMiddle
                    }
                }
                Text {
                    visible: !row.isTop && text !== ""
                    Layout.maximumWidth: 260
                    text: row.modelData.sub ?? ""
                    color: row.current ? row.softWhite : Theme.dim
                    font.pointSize: 9
                    elide: Text.ElideMiddle
                }
                Text {
                    visible: row.current
                    text: row.modelData.type === "calc" ? "↵ copy" : "↵"
                    color: row.softWhite
                    font.pointSize: 9
                }
            }
        }
    }
}
