// La ventana del lanzador (lo que antes era wofi). La lógica de cada modo
// está en services/Launcher.qml.
//
// Estilo: limpio (buscador arriba, lista plana, sin
// efectos), todo cuadrado y sin bordes. En el menú de temas cada fila lleva
// su paleta de colores a la derecha (las fuentes, escritas con ella misma) y
// en el de fondos, su miniatura. En los perfiles mac (Theme.mac) va como
// macshell: esquinas redondeadas, borde fino, fondo translúcido con desenfoque
// y la fila elegida en azul.
//
// Teclas: escribir filtra · ↑/↓ o Ctrl+K/J o Tab moverse · Enter elegir · Esc cerrar
// Clic fuera también cierra. Con pestañas (temas: Oscuros / Claros / Fuente), Tab, Shift+Tab
// y ←/→ cambian de pestaña (ese menú no tiene buscador) y ↑/↓ se mueven.
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

    // Apps, portapapeles, emojis y energía (Super+Escape) en el centro; el
    // resto de menús, arriba a la derecha bajo la barra (como estaban con wofi)
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

    // Cada vez que se abre un modo o llega una pregunta de dmenu (aunque la
    // ventana ya estuviera abierta): buscador vacío, primera fila y foco en él
    Connections {
        target: Launcher
        function onShown() {
            search.text = "";
            list.currentIndex = 0;
            search.forceActiveFocus();
        }
    }

    // ── Filtrado ──────────────────────────────────────────
    // Primero lo que contiene el texto tal cual (antes cuanto más al
    // principio), después lo que tiene las letras en orden ("ffx" → Firefox)
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
    // Elegida la primera fila, o la actual (`cur`, el tema activo) si está en la lista
    onFilteredChanged: list.currentIndex = Math.max(0, filtered.findIndex(it => it.cur))

    function accept() {
        Launcher.choose(filtered[list.currentIndex] ?? null, search.text);
    }

    // Altura máxima de la lista según el modo
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

            // ── Buscador: solo el texto, sin fondo ni lupa ──────
            // (el candado aparece únicamente al pedir una contraseña)
            // En el menú de apagar no se ve: alto 0 y transparente, pero sigue
            // existiendo para recibir las teclas (flechas, Enter, Esc)
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
                        text: Launcher.prompt || "Buscar…"
                        color: Theme.muted
                        font: search.font
                    }

                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        const n = Launcher.tabs.length;
                        if (n && (e.key === Qt.Key_Tab || e.key === Qt.Key_Right))
                            Launcher.tab = (Launcher.tab + 1) % n;
                        else if (n && (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left))
                            Launcher.tab = (Launcher.tab + n - 1) % n;
                        else if (e.key === Qt.Key_Escape)
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

            // ── Pestañas (solo en los modos que las tienen) ─────
            // La elegida, en negrita con una raya del acento debajo; en mac, una
            // píldora gris como los controles segmentados de macOS
            RowLayout {
                visible: Launcher.tabs.length > 0
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
                        radius: Theme.mac ? 8 : 0
                        color: row.selected ? Theme.launcherSel : mouse.containsMouse ? Theme.withAlpha(Theme.launcherSel, 0.5) : "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        // Fondos: miniatura del fondo
                        Image {
                            visible: !!row.modelData.image
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 27
                            source: row.modelData.image ?? ""
                            sourceSize.width: 96
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        // Símbolo (menús y emojis); las apps van sin icono
                        Text {
                            visible: !!row.modelData.glyph
                            Layout.preferredWidth: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: row.modelData.glyph ?? ""
                            color: row.selected ? (Theme.mac ? Theme.onAccent : Theme.pink) : Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 16
                        }

                        // Fuentes (pestaña Fuente de temas): cada una escrita con ella misma
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: row.modelData.text ?? ""
                            color: row.selected ? (Theme.mac ? Theme.onAccent : Theme.fg) : Theme.withAlpha(Theme.fg, Theme.mac ? 1 : 0.8)
                            font.family: row.modelData.font ?? Theme.font
                            font.pixelSize: 14
                            font.bold: row.selected && !Theme.mac
                        }

                        // Temas: su paleta sobre el fondo de su terminal ("Aa" con el
                        // color del texto, el acento y 6 colores ANSI). Cuadrada como
                        // el resto del lanzador, o en píldora con puntos en mac
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

                        // Descripción corta a la derecha (p. ej. "Navegador web")
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
