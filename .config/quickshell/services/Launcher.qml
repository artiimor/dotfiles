// Launcher/menus: replaces wofi. The logic lives here (which list is
// shown and what happens on selection); the look is in modules/LauncherWindow.qml.
//
// Modes (also from Hyprland with `qs ipc call launcher <mode>`):
//   apps        application launcher              (Super+Space)
//   power       lock, suspend, shut down...       (Super+Esc, ⏻ button)
//   clipboard   cliphist history                  (Super+Ctrl+V)
//   emoji       emoji picker                      (Super+.)
//   profiles    power profile                     (click on the bar icon)
//   themes      color theme and font              (Super+T)
//   backgrounds wallpaper of the current theme    (Super+Ctrl+B)
//   configs     desktop profile: Mac Mode / Normal Mode  (Super+Shift+T)
//   keys        Hyprland shortcut cheat sheet     (Super+?)
//   menu        main menu, like Omarchy's         (Super+M)
//   style       style: theme, font, background, config and contrast (from menu)
//   themeTypes  dark or light themes (from style)
//               (submenus open in the same window; ←/h goes back to the previous one)
//   dmenu       generic menu for scripts: used by scripts/dmenu-qs
//               (wifi with networkmanager_dmenu, bluetooth with bzmenu, webapp)
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
    property bool password: false  // dmenu: hide what you type
    property var items: []         // [{ text, icon, glyph, sub, data }]
    signal shown()                 // every time a mode opens or a dmenu question arrives

    // Each mode: window width (as it was in wofi), title, where the
    // rows come from (`items`, a function that stays bound, or `proc`, a process
    // that fills them when it finishes), whether it has no search box (short menus), whether
    // it shows the short description (`sub`) on the right and its tabs (`tabs`:
    // each row says which one it goes in with `tab`, its index; each tab has its own
    // search and its hint text in `tabPrompts`). Those without their own
    // width (profiles, and dmenu without -c) show up top right, next to the
    // bar, at 320 px; the rest, centered.
    readonly property var modes: ({
        // No title: the magnifier already says it's a search box
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
        // Main menu, style and theme types: each row opens the menu `data`
        // (with `openTab`, only that tab, without search box or tab bar)
        // except Style in Mac Mode, which opens macshell's Appearance window,
        // and contrast, which is changed with contrast-set
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
    property int tab: 0  // visible tab (index in `tabs`)
    property int openTab: -1  // tab requested on open (style menu); -1, the usual one
    readonly property bool fixedTab: openTab >= 0  // only that tab: no search box and no tab bar
    property int startIndex: 0  // row selected on open; when going back, the one you left from

    // Menus we came from ({ mode, index }), to go back with ←/h.
    // Cleared when a mode is opened with toggle (shortcut or IPC) or a dmenu arrives
    property var history: []

    // Opens a mode, or closes it if it was already open (like `pkill wofi || wofi`).
    // The main menu also closes if one of its submenus is open
    function toggle(m, float) {
        if (open && floatLaunch === !!float && (mode === m || (m === "menu" && history.length))) {
            close();
        } else {
            history = [];
            show(m, float);
        }
    }

    // "apps" mode with floatLaunch (Super+Alt+Space): the chosen app opens floating
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
        if (m === "emoji")
            emojiFile.preload = true; // read it the first time (reload() isn't enough without preload)
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

    // Whether the row opens a submenu in the same window (menu, style and theme types)
    function opensMenu(item) {
        return ["menu", "style", "themeTypes"].includes(mode) && !!item && !!modes[item.data];
    }

    // Goes back to the previous menu, on the row you left from
    function back() {
        const h = history[history.length - 1];
        history = history.slice(0, -1);
        show(h.mode);
        startIndex = h.index;
    }

    // Rows coming from a process or file: discarded if in the meantime
    // it was closed or the mode changed (otherwise they would overwrite the new one's list)
    function loaded(m, list) {
        if (open && mode === m)
            items = list;
    }

    // Non-empty lines of a command's output
    function lines(text) {
        return text.split("\n").filter(l => l);
    }

    // Called on Enter or click. `typed` is what was typed in the search box.
    function choose(item, typed) {
        const m = mode;
        if (m === "dmenu") {
            // Like dmenu: if there is no match, returns what was typed
            answerDmenu(item ? item.text : typed);
            open = false;
            return;
        }
        if (!item)
            return;
        // Menu, style and theme types: the submenu opens in the same window, without closing it
        if (opensMenu(item)) {
            history = history.concat({ mode: m, index: items.indexOf(item) });
            show(item.data, false, item.openTab);
            return;
        }
        open = false;
        // keys: only for looking, picking a row closes the cheat sheet

        if (m === "apps") {
            const e = item.data;
            const cmd = e.runInTerminal ? ["ghostty", "-e", ...e.command] : e.command;
            if (root.floatLaunch) {
                // Launched by Hyprland with the float rule (follows the process through uwsm-app),
                // centered and at 65% of the screen like in desktop mode (not maximized)
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
            // theme-set doesn't restart Quickshell (not even in Mac Mode between light and
            // dark theme): setsid only detaches it from this process
            Quickshell.execDetached(["setsid", "-f", root.themesDir + (item.font ? "/font-set" : "/theme-set"), item.data]);
        } else if (m === "backgrounds") {
            // "+": opens the theme's backgrounds folder in Dolphin (current is a link to the theme)
            Quickshell.execDetached(item.data === "+"
                ? ["sh", "-c", `mkdir -p "$1" && exec uwsm-app -- xdg-open "$1"`, "sh", root.themesDir + "/current/backgrounds"]
                : [root.themesDir + "/background-set", item.data]);
        } else if (m === "configs") {
            // config-set restarts Quickshell (this process included): setsid so it doesn't die with it
            Quickshell.execDetached(["setsid", "-f", root.themesDir + "/config-set", item.data]);
        } else if (m === "menu") {
            Quickshell.execDetached(["qs", "-p", Quickshell.shellDir + "/macshell", "ipc", "call", "appearance", "open"]);
        } else if (m === "style") {
            Quickshell.execDetached([root.themesDir + "/contrast-set", "toggle"]);
        }
    }

    // Copies and pastes into the active window (with Shift+Insert, which works in
    // almost every app). The wait is so focus returns to the window.
    function copyAndPaste(copyCmd, arg) {
        Quickshell.execDetached(["sh", "-c",
            copyCmd + ` && sleep 0.15 && hyprctl dispatch "hl.dsp.send_shortcut({ mods = 'SHIFT', key = 'Insert' })" >/dev/null`,
            "sh", arg]);
    }

    // ── Apps ──────────────────────────────────────────────
    // Quickshell reads the .desktop files gradually the first time they are requested, and
    // updates them if you install something. That's why it's a binding that recomputes
    // itself, and it is requested at start-up so it's ready when the launcher opens.
    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
        .map(e => ({ text: e.name, sub: e.genericName, icon: e.icon, keywords: e.keywords.join(" "), data: e }))

    // ── Portapapeles ──────────────────────────────────────
    Process {
        id: cliphist
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            // Each line: "<id>\t<preview>"
            onStreamFinished: root.loaded("clipboard", root.lines(text).map(l => ({
                text: l.slice(l.indexOf("\t") + 1).replace(/\s+/g, " ").slice(0, 200),
                data: l
            })))
        }
    }

    // ── Emojis ────────────────────────────────────────────
    // Read from emoji-test.txt the first time the mode opens (show), without
    // skin tone variants
    property var emojis: []
    FileView {
        id: emojiFile
        path: "/usr/share/unicode/emoji/emoji-test.txt"
        preload: false
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

    // ── Shortcut cheat sheet ─────────────────────────────────
    // Comes from `hyprctl binds`: only the shortcuts with { description = "..." } in
    // hypr/config/*.lua, so it's always up to date with the config.
    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const mods = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]];
                const keyName = k => {
                    if (k === "code:10")
                        return "1-0"; // the workspace loops only describe 1
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

    // ── Color themes ────────────────────────────────────
    // Every folder in ~/.config/themes with a theme.json is a theme; picking
    // one runs theme-set, which recolors everything (see that script). Each row
    // has its palette (terminal background and text, accent and 6 ANSI colors) to
    // preview it before picking, and a sun or a moon depending on light or dark. They go in
    // two tabs, dark and light; it opens on the active theme's tab. The third,
    // Font, is the monospace font (terminals, hyprbars...), separate from the
    // theme: set by font-set, and each row is written in its font. Each tab
    // has its own search (see LauncherWindow.qml). From the style menu
    // it opens on a single fixed tab, without search box or tabs (`fixedTab`).
    readonly property string themesDir: Quickshell.env("HOME") + "/.config/themes"

    // Nerd Fonts whose name isn't the original font's (license): so
    // they are also found by searching for the original
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

    // Mark of the current item in themes, backgrounds and configs
    function curMark(isCur) {
        return isCur ? "  " + String.fromCodePoint(0xF012C) : "";
    }

    Process {
        id: themeList
        // `theme-set --list`: each line, a JSON { dir, name, cur, light, bg, fg, colors };
        // after it, `font-set --list`: { font, cur }
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
                        // Sun (light) or moon (dark)
                        glyph: String.fromCodePoint(t.light ? 0xF0599 : 0xF0594),
                        palette: { bg: t.bg, fg: t.fg, colors: t.colors },
                        tab: t.light ? 1 : 0,
                        cur: t.cur, // the window selects it on open
                        keywords: t.dir,
                        data: t.dir
                    };
                });
                // Only if the theme menu is still open (with ←/h you may already be back in the style one)
                if (root.open && root.mode === "themes")
                    root.tab = root.openTab >= 0 ? root.openTab : list.find(i => i.cur && !i.font)?.tab ?? 0;
                root.loaded("themes", list);
            }
        }
    }

    // ── Backgrounds of the current theme ────────────────────────────
    // `background-set` gives "<background>\t<path>\t<1 if current>"
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

    // ── Configs (desktop profiles) ─────────────────
    // `config-set --list` gives "<profile>\t<name>\t<1 if current>" (only Mac Mode
    // and Normal Mode: Mac light or dark is decided by the color theme); picking
    // one, config-set changes Hyprland, the bar, icons and Qt (see that script)
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

    // ── dmenu (for scripts) ──────────────────────────────
    // scripts/dmenu-qs leaves the options in <dir>/items and waits for the answer
    // in the fifo <dir>/out. Empty string = cancelled.
    // With `center` (dmenu-qs -c, used by webapp) it shows centered and wider.
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
