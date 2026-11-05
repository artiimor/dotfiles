// Lanzador/menús: sustituye a wofi. Aquí está la lógica (qué lista se
// muestra y qué pasa al elegir); el aspecto está en modules/LauncherWindow.qml.
//
// Modos (también desde Hyprland con `qs ipc call launcher <modo>`):
//   apps        lanzador de aplicaciones          (Super+Espacio)
//   power       bloquear, suspender, apagar...    (Super+Esc, botón ⏻)
//   clipboard   historial de cliphist             (Super+Ctrl+V)
//   emoji       selector de emojis                (Super+.)
//   profiles    perfil de energía                 (clic en el icono de la barra)
//   themes      tema de colores                   (Super+Ctrl+T)
//   dmenu       menú genérico para scripts: lo usa scripts/dmenu-qs
//               (wifi con networkmanager_dmenu, bluetooth con bzmenu)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property bool open: false
    property string mode: ""
    property string prompt: ""
    property bool password: false  // dmenu: ocultar lo que escribes
    property var items: []         // [{ text, icon, glyph, sub, data }]

    // Tamaño y sitio de la ventana según el modo (como estaba en wofi)
    readonly property int width: ({ apps: 360, clipboard: 640, emoji: 420, power: 220, themes: 260 })[mode] ?? 320
    readonly property bool centered: ["apps", "clipboard", "emoji", "power", "themes"].includes(mode)

    // Abre un modo, o lo cierra si ya estaba abierto (como `pkill wofi || wofi`)
    function toggle(m) {
        if (open && mode === m)
            close();
        else
            show(m);
    }

    function show(m) {
        cancelDmenu();
        mode = m;
        password = false;
        if (m === "apps") {
            prompt = ""; // sin texto: la lupa ya dice que es un buscador
            items = Qt.binding(() => root.apps);
        } else if (m === "power") {
            prompt = "Energía";
            items = [
                { text: "Bloquear", glyph: "󰌾", data: "lock" },
                { text: "Suspender", glyph: "󰤄", data: "suspend" },
                { text: "Cerrar sesión", glyph: "󰍃", data: "logout" },
                { text: "Reiniciar", glyph: "󰜉", data: "reboot" },
                { text: "Apagar", glyph: "󰐥", data: "poweroff" }
            ];
        } else if (m === "profiles") {
            prompt = "Perfil de energía";
            const p = PowerProfiles.profile;
            const mark = v => p === v ? "  󰄬" : "";
            items = [
                { text: "Rendimiento" + mark(PowerProfile.Performance), glyph: "󰓅", data: "performance" },
                { text: "Equilibrado" + mark(PowerProfile.Balanced), glyph: "󰾅", data: "balanced" },
                { text: "Ahorro" + mark(PowerProfile.PowerSaver), glyph: "󰾆", data: "power-saver" }
            ];
        } else if (m === "clipboard") {
            prompt = "Portapapeles";
            items = [];
            cliphist.running = true;
        } else if (m === "emoji") {
            prompt = "Emoji";
            items = emojis;
        } else if (m === "themes") {
            prompt = "Tema";
            items = [];
            themeList.running = true;
        }
        open = true;
    }

    function close() {
        cancelDmenu();
        open = false;
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
        open = false;

        if (m === "apps") {
            const e = item.data;
            const cmd = e.runInTerminal ? ["kitty", "-e", ...e.command] : e.command;
            Quickshell.execDetached(["uwsm", "app", "--", ...cmd]);
        } else if (m === "power") {
            const cmds = {
                lock: "loginctl lock-session",
                suspend: "loginctl lock-session && sleep 0.5 && systemctl suspend",
                logout: "uwsm stop",
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
            Quickshell.execDetached([root.themesDir + "/theme-set", item.data]);
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
            onStreamFinished: {
                // Cada línea: "<id>\t<vista previa>"
                root.items = text.split("\n").filter(l => l).map(l => ({
                    text: l.slice(l.indexOf("\t") + 1).replace(/\s+/g, " ").slice(0, 200),
                    data: l
                }));
            }
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

    // ── Temas de color ────────────────────────────────────
    // Cada carpeta de ~/.config/themes con un theme.json es un tema; al elegir
    // uno se ejecuta theme-set, que recolorea todo (ver ese script)
    readonly property string themesDir: Quickshell.env("HOME") + "/.config/themes"

    Process {
        id: themeList
        // Cada línea: "<carpeta>\t<nombre bonito>\t<1 si es el actual>"
        command: ["python3", "-c", `
import json, os
d = os.path.expanduser("~/.config/themes")
try: cur = os.path.basename(os.readlink(d + "/current"))
except OSError: cur = ""
for t in sorted(os.listdir(d)):
    f = f"{d}/{t}/theme.json"
    if t != "current" and os.path.isfile(f):
        print(t, json.load(open(f)).get("name", t), int(t == cur), sep="\t")
`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l).map(l => {
                    const [dir, name, cur] = l.split("\t");
                    return {
                        text: name + (cur === "1" ? "  " + String.fromCodePoint(0xF012C) : ""),
                        glyph: String.fromCodePoint(0xF03D8),
                        data: dir
                    };
                });
            }
        }
    }

    // ── dmenu (para scripts) ──────────────────────────────
    // scripts/dmenu-qs deja las opciones en <dir>/items y espera la respuesta
    // en el fifo <dir>/out. Cadena vacía = cancelado.
    property string dmenuDir: ""

    function showDmenu(dir, p, pass) {
        cancelDmenu();
        dmenuDir = dir;
        mode = "dmenu";
        prompt = p || "Elegir";
        password = pass;
        items = [];
        dmenuItems.path = "";
        dmenuItems.path = dir + "/items";
        open = true;
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
        onLoaded: root.items = text().split("\n").filter(l => l).map(l => ({ text: l }))
    }

    IpcHandler {
        target: "launcher"
        function apps(): void { root.toggle("apps"); }
        function power(): void { root.toggle("power"); }
        function clipboard(): void { root.toggle("clipboard"); }
        function emoji(): void { root.toggle("emoji"); }
        function profiles(): void { root.toggle("profiles"); }
        function themes(): void { root.toggle("themes"); }
        function close(): void { root.close(); }
        function dmenu(dir: string, prompt: string, password: bool): void { root.showDmenu(dir, prompt, password); }
    }
}
