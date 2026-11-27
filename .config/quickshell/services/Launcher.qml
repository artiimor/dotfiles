// Lanzador/menús: sustituye a wofi. Aquí está la lógica (qué lista se
// muestra y qué pasa al elegir); el aspecto está en modules/LauncherWindow.qml.
//
// Modos (también desde Hyprland con `qs ipc call launcher <modo>`):
//   apps        lanzador de aplicaciones          (Super+Espacio)
//   power       bloquear, suspender, apagar...    (Super+Esc, botón ⏻)
//   clipboard   historial de cliphist             (Super+Ctrl+V)
//   emoji       selector de emojis                (Super+.)
//   profiles    perfil de energía                 (clic en el icono de la barra)
//   themes      tema de colores y fuente          (Super+T)
//   backgrounds fondo de pantalla del tema actual (Super+Ctrl+B)
//   configs     perfil del escritorio: Modo Mac / Modo normal  (Super+Shift+T)
//   keys        chuleta de atajos de Hyprland     (Super+?)
//   menu        menú principal, como el de Omarchy (Super+M)
//   style       estilo: tema, fuente, fondo, config y contraste (desde menu)
//   themeTypes  temas oscuros o claros (desde style)
//               (los submenús se abren en la misma ventana; ←/h vuelve al anterior)
//   dmenu       menú genérico para scripts: lo usa scripts/dmenu-qs
//               (wifi con networkmanager_dmenu, bluetooth con bzmenu, webapp)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    property bool open: false
    property string mode: ""
    property string prompt: ""
    property bool password: false  // dmenu: ocultar lo que escribes
    property var items: []         // [{ text, icon, glyph, sub, data }]
    signal shown()                 // cada vez que se abre un modo o llega una pregunta de dmenu

    // Cada modo: ancho de la ventana (como estaba en wofi), título, de dónde salen
    // las filas (`items`, una función que se queda enlazada, o `proc`, un proceso
    // que las rellena al terminar), si va sin buscador (menús cortos), si
    // enseña la descripción corta (`sub`) a la derecha y sus pestañas (`tabs`:
    // cada fila dice en cuál va con `tab`, su índice; cada pestaña tiene su
    // búsqueda y su texto de ayuda en `tabPrompts`). Los que no tienen ancho
    // propio (profiles, y dmenu sin -c) salen arriba a la derecha, junto a la
    // barra, con 320 px; los demás, centrados.
    readonly property var modes: ({
        // Sin título: la lupa ya dice que es un buscador
        apps: { width: 360, prompt: "", items: () => root.apps, showSub: true },
        clipboard: { width: 640, prompt: I18n.tr("Clipboard"), proc: cliphist },
        emoji: { width: 420, prompt: "Emoji", items: () => root.emojis },
        power: { width: 220, prompt: I18n.tr("Power"), noSearch: true, items: () => [
            { text: I18n.tr("Lock"), glyph: "󰌾", data: "lock" },
            { text: I18n.tr("Suspend"), glyph: "󰤄", data: "suspend" },
            { text: I18n.tr("Log out"), glyph: "󰍃", data: "logout" },
            { text: I18n.tr("Restart"), glyph: "󰜉", data: "reboot" },
            { text: I18n.tr("Shut down"), glyph: "󰐥", data: "poweroff" }
        ] },
        themes: { width: 420, prompt: I18n.tr("Theme"), proc: themeList, tabs: [I18n.tr("Dark"), I18n.tr("Light"), I18n.tr("Font")],
                  tabPrompts: [I18n.tr("Search dark themes…"), I18n.tr("Search light themes…"), I18n.tr("Search fonts…")] },
        backgrounds: { width: 420, prompt: I18n.tr("Background"), noSearch: true, proc: backgroundList },
        configs: { width: 260, prompt: "Config", noSearch: true, proc: configList },
        keys: { width: 520, prompt: I18n.tr("Shortcuts"), proc: binds, showSub: true },
        // Menú principal, estilo y tipos de tema: cada fila abre el menú `data`
        // (con `openTab`, solo esa pestaña, sin buscador ni barra de pestañas)
        // salvo Estilo en Modo Mac, que abre la ventana Appearance de macshell,
        // y el contraste, que se cambia con contrast-set
        menu: { width: 260, prompt: I18n.tr("Menu"), noSearch: true, showSub: true, items: () => [
            { text: I18n.tr("Style"), glyph: String.fromCodePoint(0xF00E3), sub: "›", data: Theme.mac ? "appearance" : "style" }
        ] },
        style: { width: 300, prompt: I18n.tr("Style"), noSearch: true, showSub: true, items: () => [
            { text: I18n.tr("Theme"), glyph: String.fromCodePoint(0xF03D8), sub: "›", data: "themeTypes" },
            { text: I18n.tr("Font"), glyph: String.fromCodePoint(0xF06D6), sub: "›", data: "themes", openTab: 2 },
            { text: I18n.tr("Background"), glyph: String.fromCodePoint(0xF02E9), sub: "›", data: "backgrounds" },
            { text: I18n.tr("Mode"), glyph: String.fromCodePoint(Theme.mac ? 0xF0035 : 0xF0379),
              sub: (Theme.mac ? I18n.tr("Mac mode") : I18n.tr("Normal mode")) + "  ›", data: "configs" },
            { text: I18n.tr("Increase contrast"), glyph: String.fromCodePoint(0xF0197),
              sub: Theme.contrast ? I18n.tr("On") : I18n.tr("Off"), data: "contrast" }
        ] },
        themeTypes: { width: 260, prompt: I18n.tr("Theme"), noSearch: true, showSub: true, items: () => [
            { text: I18n.tr("Dark"), glyph: String.fromCodePoint(0xF0594), sub: "›", data: "themes", openTab: 0 },
            { text: I18n.tr("Light"), glyph: String.fromCodePoint(0xF0599), sub: "›", data: "themes", openTab: 1 }
        ] },
        profiles: { prompt: I18n.tr("Power profile"), items: () => {
            const mark = v => root.curMark(PowerProfiles.profile === v);
            return [
                { text: I18n.tr("Performance") + mark(PowerProfile.Performance), glyph: "󰓅", data: "performance" },
                { text: I18n.tr("Balanced") + mark(PowerProfile.Balanced), glyph: "󰾅", data: "balanced" },
                { text: I18n.tr("Power saver") + mark(PowerProfile.PowerSaver), glyph: "󰾆", data: "power-saver" }
            ];
        } }
    })
    readonly property var modeInfo: (mode === "dmenu" ? dmenuInfo : modes[mode]) ?? {}
    readonly property int width: modeInfo.width ?? 320
    readonly property bool centered: !!modeInfo.width
    readonly property bool noSearch: !!modeInfo.noSearch || fixedTab
    readonly property bool showSub: !!modeInfo.showSub
    readonly property var tabs: modeInfo.tabs ?? []
    readonly property string tabPrompt: (modeInfo.tabPrompts ?? [])[tab] ?? ""
    property int tab: 0  // pestaña visible (índice en `tabs`)
    property int openTab: -1  // pestaña pedida al abrir (menú de estilo); -1, la de siempre
    readonly property bool fixedTab: openTab >= 0  // solo esa pestaña: sin buscador ni barra de pestañas
    property int startIndex: 0  // fila elegida al abrir; al volver, la de la que se salió

    // Menús de los que se ha venido ({ mode, index }), para volver con ←/h.
    // Se vacía al abrir un modo con toggle (atajo o IPC) o llegar un dmenu
    property var history: []

    // Abre un modo, o lo cierra si ya estaba abierto (como `pkill wofi || wofi`).
    // El menú principal también se cierra si está abierto uno de sus submenús
    function toggle(m, float) {
        if (open && floatLaunch === !!float && (mode === m || (m === "menu" && history.length))) {
            close();
        } else {
            history = [];
            show(m, float);
        }
    }

    // Modo "apps" con floatLaunch (Super+Alt+Espacio): la app elegida se abre flotante
    property bool floatLaunch: false

    function show(m, float, t) {
        cancelDmenu();
        mode = m;
        floatLaunch = !!float;
        password = false;
        openTab = t ?? -1;
        tab = Math.max(0, openTab);
        startIndex = 0;
        const d = modes[m];
        prompt = d.prompt;
        if (d.proc) {
            items = [];
            d.proc.running = true;
        } else {
            items = Qt.binding(d.items);
        }
        open = true;
        shown();
    }

    function close() {
        cancelDmenu();
        open = false;
    }

    // Si la fila abre un submenú en la misma ventana (menú, estilo y tipos de tema)
    function opensMenu(item) {
        return ["menu", "style", "themeTypes"].includes(mode) && !!item && !!modes[item.data];
    }

    // Vuelve al menú anterior, en la fila de la que se salió
    function back() {
        const h = history[history.length - 1];
        history = history.slice(0, -1);
        show(h.mode);
        startIndex = h.index;
    }

    // Filas que llegan de un proceso o archivo: se descartan si mientras tanto
    // se ha cerrado o cambiado de modo (si no, pisarían la lista del nuevo)
    function loaded(m, list) {
        if (open && mode === m)
            items = list;
    }

    // Líneas no vacías de la salida de un comando
    function lines(text) {
        return text.split("\n").filter(l => l);
    }

    // Se llama al pulsar Enter o hacer clic. `typed` es lo escrito en el buscador.
    function choose(item, typed) {
        const m = mode;
        if (m === "dmenu") {
            // Como dmenu: si no hay coincidencia, devuelve lo escrito
            answerDmenu(item ? item.text : typed);
            open = false;
            return;
        }
        if (!item)
            return;
        // Menú, estilo y tipos de tema: el submenú se abre en la misma ventana, sin cerrarla
        if (opensMenu(item)) {
            history = history.concat({ mode: m, index: items.indexOf(item) });
            show(item.data, false, item.openTab);
            return;
        }
        open = false;
        // keys: solo es para mirar, elegir una fila cierra la chuleta

        if (m === "apps") {
            const e = item.data;
            const cmd = e.runInTerminal ? ["ghostty", "-e", ...e.command] : e.command;
            if (root.floatLaunch) {
                // Lo lanza Hyprland con la regla float (sigue al proceso a través de uwsm-app),
                // centrada y al 65% de la pantalla como en el modo escritorio (no maximizada)
                const q = a => "'" + String(a).replace(/'/g, "'\\''") + "'";
                const sh = ["uwsm-app", "--", ...cmd].map(q).join(" ");
                Hypr.dispatch(`hl.dsp.exec_cmd(${JSON.stringify(sh)}, { float = true, size = { "monitor_w*0.65", "monitor_h*0.65" }, center = true })`);
            } else {
                Quickshell.execDetached(["uwsm-app", "--", ...cmd]);
            }
        } else if (m === "power") {
            const cmds = {
                lock: "loginctl lock-session",
                suspend: "loginctl lock-session && sleep 0.5 && systemctl suspend",
                logout: "if uwsm check is-active; then uwsm stop; else loginctl terminate-session \"$XDG_SESSION_ID\"; fi",
                reboot: "systemctl reboot",
                poweroff: "systemctl poweroff"
            };
            Quickshell.execDetached(["sh", "-c", cmds[item.data]]);
        } else if (m === "profiles") {
            Quickshell.execDetached(["powerprofilesctl", "set", item.data]);
        } else if (m === "clipboard") {
            copyAndPaste(`printf '%s' "$1" | cliphist decode | wl-copy`, item.data);
        } else if (m === "emoji") {
            copyAndPaste(`printf '%s' "$1" | wl-copy`, item.glyph);
        } else if (m === "themes") {
            // theme-set no reinicia Quickshell (tampoco en Modo Mac entre tema claro y
            // oscuro): setsid solo lo separa de este proceso
            Quickshell.execDetached(["setsid", "-f", root.themesDir + (item.font ? "/font-set" : "/theme-set"), item.data]);
        } else if (m === "backgrounds") {
            // "+": abre en Dolphin la carpeta de fondos del tema (current es un enlace al tema)
            Quickshell.execDetached(item.data === "+"
                ? ["sh", "-c", `mkdir -p "$1" && exec uwsm-app -- xdg-open "$1"`, "sh", root.themesDir + "/current/backgrounds"]
                : [root.themesDir + "/background-set", item.data]);
        } else if (m === "configs") {
            // config-set reinicia Quickshell (este proceso incluido): setsid para que no muera con él
            Quickshell.execDetached(["setsid", "-f", root.themesDir + "/config-set", item.data]);
        } else if (m === "menu") {
            Quickshell.execDetached(["qs", "-p", Quickshell.shellDir + "/macshell", "ipc", "call", "appearance", "open"]);
        } else if (m === "style") {
            Quickshell.execDetached([root.themesDir + "/contrast-set", "toggle"]);
        }
    }

    // Copia y pega en la ventana activa (con Shift+Insert, que funciona en
    // casi todas las apps). La espera es para que el foco vuelva a la ventana.
    function copyAndPaste(copyCmd, arg) {
        Quickshell.execDetached(["sh", "-c",
            copyCmd + ` && sleep 0.15 && hyprctl dispatch "hl.dsp.send_shortcut({ mods = 'SHIFT', key = 'Insert' })" >/dev/null`,
            "sh", arg]);
    }

    // ── Apps ──────────────────────────────────────────────
    // Quickshell lee los .desktop poco a poco la primera vez que se piden, y
    // los actualiza si instalas algo. Por eso es un binding que se recalcula
    // solo, y se pide al arrancar para que esté lista al abrir el lanzador.
    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
        .map(e => ({ text: e.name, sub: e.genericName, icon: e.icon, keywords: e.keywords.join(" "), data: e }))

    // ── Portapapeles ──────────────────────────────────────
    Process {
        id: cliphist
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            // Cada línea: "<id>\t<vista previa>"
            onStreamFinished: root.loaded("clipboard", root.lines(text).map(l => ({
                text: l.slice(l.indexOf("\t") + 1).replace(/\s+/g, " ").slice(0, 200),
                data: l
            })))
        }
    }

    // ── Emojis ────────────────────────────────────────────
    // Se lee una vez de emoji-test.txt, sin variantes de tono de piel
    property var emojis: []
    FileView {
        path: "/usr/share/unicode/emoji/emoji-test.txt"
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                if (!line.includes("; fully-qualified") || line.includes("skin tone"))
                    continue;
                const m = line.match(/# (\S+) E[\d.]+ (.*)$/);
                if (m)
                    out.push({ text: m[2], glyph: m[1] });
            }
            root.emojis = out;
        }
    }

    // ── Chuleta de atajos ─────────────────────────────────
    // Sale de `hyprctl binds`: solo los atajos con { description = "..." } en
    // hypr/config/*.lua, así que está siempre al día con la config.
    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const mods = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]];
                const keyName = k => {
                    if (k === "code:10")
                        return "1-0"; // los bucles de workspaces solo describen el 1
                    const m = k.match(/^code:(\d+)$/);
                    if (m && +m[1] >= 11 && +m[1] <= 19)
                        return String((+m[1] - 9) % 10);
                    return ({ "mouse:272": I18n.tr("Left click"), "mouse:273": I18n.tr("Right click"), mouse_up: I18n.tr("Wheel"), mouse_down: I18n.tr("Wheel"),
                              Return: "Enter", Escape: "Esc", period: ".", slash: "?", Minus: "-", Plus: "+" })[k]
                        ?? (k.length === 1 ? k.toUpperCase() : k);
                };
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {}
                root.loaded("keys", list.filter(b => b.has_description).map(b => {
                    const combo = mods.filter(([bit]) => b.modmask & bit).map(([, n]) => n).concat(keyName(b.key)).join(" + ");
                    return { text: I18n.tr(b.description), sub: combo, keywords: combo };
                }));
            }
        }
    }

    // ── Temas de color ────────────────────────────────────
    // Cada carpeta de ~/.config/themes con un theme.json es un tema; al elegir
    // uno se ejecuta theme-set, que recolorea todo (ver ese script). Cada fila
    // lleva su paleta (fondo y texto del terminal, acento y 6 colores ANSI) para
    // verla antes de elegir, y un sol o una luna según sea claro u oscuro. Van en
    // dos pestañas, oscuros y claros; se abre en la del tema activo. La tercera,
    // Fuente, es la fuente monoespaciada (terminales, hyprbars...), aparte del
    // tema: la pone font-set, y cada fila se escribe con su fuente. Cada pestaña
    // tiene su propia búsqueda (ver LauncherWindow.qml). Desde el menú de estilo
    // se abre en una sola pestaña fija, sin buscador ni pestañas (`fixedTab`).
    readonly property string themesDir: Quickshell.env("HOME") + "/.config/themes"

    // Nerd Fonts cuyo nombre no es el de la fuente original (licencia): para
    // encontrarlas también buscando el original
    readonly property var fontAliases: ({
        BlexMono: "IBM Plex Mono",
        CaskaydiaCove: "Cascadia Code",
        CaskaydiaMono: "Cascadia Mono",
        SauceCodePro: "Source Code Pro",
        MonaspiceAr: "Monaspace Argon", MonaspiceKr: "Monaspace Krypton",
        MonaspiceNe: "Monaspace Neon", MonaspiceRn: "Monaspace Radon",
        MonaspiceXe: "Monaspace Xenon",
        LiterationMono: "Liberation Mono",
        Hurmit: "Hermit"
    })

    // Marca del elemento actual en temas, fondos y configs
    function curMark(isCur) {
        return isCur ? "  " + String.fromCodePoint(0xF012C) : "";
    }

    Process {
        id: themeList
        // `theme-set --list`: cada línea, un JSON { dir, name, cur, light, bg, fg, colors };
        // detrás, `font-set --list`: { font, cur }
        command: ["sh", "-c", '"$1/theme-set" --list; "$1/font-set" --list', "sh", root.themesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.lines(text).map(l => {
                    const t = JSON.parse(l);
                    if (t.font) {
                        const name = t.font.replace(" Nerd Font", "");
                        return {
                            text: name + root.curMark(t.cur),
                            keywords: root.fontAliases[name] ?? "",
                            glyph: String.fromCodePoint(0xF06D6), // nf-md-format_font
                            font: t.font,
                            tab: 2,
                            cur: t.cur,
                            data: t.font
                        };
                    }
                    return {
                        text: t.name + root.curMark(t.cur),
                        // Sol (claro) o luna (oscuro)
                        glyph: String.fromCodePoint(t.light ? 0xF0599 : 0xF0594),
                        palette: { bg: t.bg, fg: t.fg, colors: t.colors },
                        tab: t.light ? 1 : 0,
                        cur: t.cur, // la ventana la deja elegida al abrir
                        keywords: t.dir,
                        data: t.dir
                    };
                });
                // Solo si sigue abierto el menú de temas (con ←/h se puede haber vuelto ya al de estilo)
                if (root.open && root.mode === "themes")
                    root.tab = root.openTab >= 0 ? root.openTab : list.find(i => i.cur && !i.font)?.tab ?? 0;
                root.loaded("themes", list);
            }
        }
    }

    // ── Fondos del tema actual ────────────────────────────
    // `background-set` da "<fondo>\t<ruta>\t<1 si es el actual>"
    Process {
        id: backgroundList
        command: [root.themesDir + "/background-set"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loaded("backgrounds", root.lines(text).map(l => {
                    const [name, path, cur] = l.split("\t");
                    return {
                        text: (name === "pepes" ? "Pepes" : name.replace(/\.[^.]+$/, "")) + root.curMark(cur === "1"),
                        image: "file://" + path,
                        data: name
                    };
                }).concat({ text: I18n.tr("＋ Add wallpapers…"), data: "+" }));
            }
        }
    }

    // ── Configs (perfiles del escritorio) ─────────────────
    // `config-set --list` da "<perfil>\t<nombre>\t<1 si es el actual>" (solo Modo Mac
    // y Modo normal: Mac claro u oscuro lo decide el tema de colores); al elegir
    // uno, config-set cambia Hyprland, la barra, iconos y Qt (ver ese script)
    Process {
        id: configList
        command: [root.themesDir + "/config-set", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loaded("configs", root.lines(text).map(l => {
                    const [id, name, cur] = l.split("\t");
                    return {
                        text: name + root.curMark(cur === "1"),
                        glyph: id === "mac" ? String.fromCodePoint(0xF0035) : String.fromCodePoint(0xF0379),
                        data: id
                    };
                }));
            }
        }
    }

    // ── dmenu (para scripts) ──────────────────────────────
    // scripts/dmenu-qs deja las opciones en <dir>/items y espera la respuesta
    // en el fifo <dir>/out. Cadena vacía = cancelado.
    // Con `center` (dmenu-qs -c, lo usa webapp) sale centrado y más ancho.
    property string dmenuDir: ""
    property var dmenuInfo: ({})

    function showDmenu(dir, p, pass, center) {
        cancelDmenu();
        dmenuDir = dir;
        dmenuInfo = center ? { width: 420 } : {};
        history = [];
        mode = "dmenu";
        prompt = p || I18n.tr("Choose");
        password = pass;
        items = [];
        dmenuItems.path = dir + "/items";
        open = true;
        shown();
    }

    function answerDmenu(text) {
        if (!dmenuDir)
            return;
        Quickshell.execDetached(["sh", "-c", `printf '%s' "$1" > "$2"`, "sh", text ?? "", dmenuDir + "/out"]);
        dmenuDir = "";
    }
    function cancelDmenu() { answerDmenu(""); }

    FileView {
        id: dmenuItems
        onLoaded: root.loaded("dmenu", root.lines(text()).map(l => ({ text: l })))
    }

    IpcHandler {
        target: "launcher"
        function apps(): void { root.toggle("apps"); }
        function appsFloat(): void { root.toggle("apps", true); }
        function power(): void { root.toggle("power"); }
        function clipboard(): void { root.toggle("clipboard"); }
        function emoji(): void { root.toggle("emoji"); }
        function profiles(): void { root.toggle("profiles"); }
        function themes(): void { root.toggle("themes"); }
        function backgrounds(): void { root.toggle("backgrounds"); }
        function configs(): void { root.toggle("configs"); }
        function keys(): void { root.toggle("keys"); }
        function menu(): void { root.toggle("menu"); }
        function style(): void { root.toggle("style"); }
        function close(): void { root.close(); }
        function dmenu(dir: string, prompt: string, password: bool, center: bool): void { root.showDmenu(dir, prompt, password, center); }
    }
}
