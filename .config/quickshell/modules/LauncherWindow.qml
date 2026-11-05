// La ventana del lanzador (lo que antes era wofi). La lógica de cada modo
// está en services/Launcher.qml.
//
// Estilo: limpio (buscador arriba, lista plana, sin
// efectos), todo cuadrado y sin bordes.
//
// Teclas: escribir filtra · ↑/↓ o Ctrl+K/J o Tab moverse · Enter elegir · Esc cerrar
// Clic fuera también cierra.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services

PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Launcher.open

    // Apps, portapapeles, emojis y energía (Super+Escape) en el centro; el
    // resto de menús, arriba a la derecha bajo la barra (como estaban con wofi)
    anchors {
        top: !Launcher.centered
        right: !Launcher.centered
    }
    margins {
        top: Theme.barHeight + Theme.gap * 2
        right: Theme.gap
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    implicitWidth: Launcher.width
    implicitHeight: box.implicitHeight
    color: "transparent"

    HyprlandFocusGrab {
        windows: [win]
        active: win.visible
        onCleared: Launcher.close()
    }

    // Al abrir: buscador vacío y foco en él
    onVisibleChanged: if (visible) {
        search.text = "";
        list.currentIndex = 0;
        search.forceActiveFocus();
    }

    // ── Filtrado ──────────────────────────────────────────
    // Primero lo que contiene el texto tal cual (antes cuanto más al
    // principio), después lo que tiene las letras en orden ("ffx" → Firefox)
    readonly property var filtered: {
        const q = search.text.toLowerCase().trim();
        const all = Launcher.items;
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
                let j = 0;
                for (const c of hay) if (c === q[j]) j++;
                if (j === q.length)
                    score = 1;
            }
            if (score >= 0)
                scored.push({ it, score });
        }
        return scored.sort((a, b) => b.score - a.score).map(s => s.it);
    }
    onFilteredChanged: list.currentIndex = 0

    function accept() {
        Launcher.choose(filtered[list.currentIndex] ?? null, search.text);
    }

    // Altura máxima de la lista según el modo
    readonly property int maxRows: Launcher.centered ? 8 : 6
    readonly property int rowHeight: 38
    // Colores propios del launcher (vienen del tema: launcherBg / launcherSel)
    readonly property color bgColor: Theme.launcherBg
    readonly property color selColor: Theme.launcherSel
    // Menús cortos (apagar, temas): sin buscador
    readonly property bool noSearch: ["power", "themes"].includes(Launcher.mode)

    Rectangle {
        id: box
        width: Launcher.width
        implicitHeight: column.implicitHeight + 28
        color: win.bgColor

        ColumnLayout {
            id: column
            x: 14
            y: 14
            width: parent.width - 28
            spacing: win.noSearch ? 0 : 12

            // ── Buscador: solo el texto, sin fondo ni lupa ──────
            // (el candado aparece únicamente al pedir una contraseña)
            // En el menú de apagar no se ve: alto 0 y transparente, pero sigue
            // existiendo para recibir las teclas (flechas, Enter, Esc)
            Item {
                Layout.fillWidth: true
                implicitHeight: win.noSearch ? 0 : 36
                Layout.preferredHeight: implicitHeight
                Layout.maximumHeight: implicitHeight
                opacity: win.noSearch ? 0 : 1

                Text {
                    id: searchIcon
                    visible: Launcher.password
                    width: visible ? implicitWidth : 0
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    color: Theme.pink
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
                    readOnly: win.noSearch
                    clip: true

                    // Sin cursor visible
                    cursorDelegate: Item {}

                    Text {
                        visible: !search.text
                        text: Launcher.prompt || "Buscar…"
                        color: Theme.muted
                        font: search.font
                    }

                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if (e.key === Qt.Key_Escape)
                            Launcher.close();
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                            win.accept();
                        else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (ctrl && e.key === Qt.Key_J))
                            list.incrementCurrentIndex();
                        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (ctrl && e.key === Qt.Key_K))
                            list.decrementCurrentIndex();
                        else if (e.key === Qt.Key_PageDown)
                            list.currentIndex = Math.min(list.count - 1, list.currentIndex + win.maxRows);
                        else if (e.key === Qt.Key_PageUp)
                            list.currentIndex = Math.max(0, list.currentIndex - win.maxRows);
                        else
                            return;
                        e.accepted = true;
                    }
                }
            }

            // ── Resultados ─────────────────────────────────────
            ListView {
                id: list
                Layout.fillWidth: true
                // Alto fijo según los items del modo (sin filtrar): no encoge al escribir
                implicitHeight: Math.min(Launcher.items.length, win.maxRows) * win.rowHeight
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

                    // Fila elegida: solo un bloque de fondo
                    Rectangle {
                        anchors.fill: parent
                        color: row.selected ? win.selColor : mouse.containsMouse ? Qt.rgba(win.selColor.r, win.selColor.g, win.selColor.b, 0.5) : "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        // Símbolo (menús y emojis); las apps van sin icono
                        Text {
                            visible: !!row.modelData.glyph
                            Layout.preferredWidth: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: row.modelData.glyph ?? ""
                            color: row.selected ? Theme.pink : Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 16
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: row.modelData.text ?? ""
                            color: row.selected ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.8)
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.bold: row.selected
                        }

                        // Descripción corta a la derecha (p. ej. "Navegador web")
                        Text {
                            visible: !!row.modelData.sub && Launcher.mode === "apps"
                            Layout.maximumWidth: 180
                            elide: Text.ElideRight
                            text: row.modelData.sub ?? ""
                            color: Theme.muted
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

        // Encima del hueco de la lista, para no cambiar el alto de la caja
        Text {
            visible: list.visible && list.count === 0 && !Launcher.password && Launcher.mode !== "dmenu"
            x: column.x + list.x + (list.width - width) / 2
            y: column.y + list.y + (list.height - height) / 2
            text: "¯\\_(ツ)_/¯  nada por aquí"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
