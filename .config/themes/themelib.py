# Lo común a theme-set, config-set, background-set y font-set: rutas, tema actual, perfil
# guardado, escritura de archivos, avisos a Quickshell y traducción (tr). No es un
# tema (no tiene theme.json): lo importan ellos, que se ejecutan desde esta
# carpeta (sys.path[0]) y ponen antes sys.dont_write_bytecode = True para que no
# aparezca __pycache__ aquí.
#
# Los scripts de bash (install.sh, quickshell/scripts/webapp...) traducen con
#   python3 ~/.config/themes/themelib.py tr "Text %1" arg

import importlib.util
import json
import os
import subprocess
import sys
from importlib.machinery import SourceFileLoader

HOME = os.path.expanduser("~")
CONF = f"{HOME}/.config"
THEMES = f"{CONF}/themes"
CURRENT = f"{THEMES}/current"
PROFILE_STATE = f"{HOME}/.local/state/desktop-profile"  # lo escribe config-set

QUIET = dict(stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# THEMES_NO_RELOAD=1: se escriben los archivos pero no se avisa a nada de fuera
# (Quickshell, Hyprland, terminales, Neovim, gsettings, notificaciones). Para los
# tests: con HOME temporal no se toca lo del usuario, pero gsettings sí escribiría
# en su dconf real. Todo pasa por run_quiet(), salvo reload_nvim() de theme-set y
# restart_shell() de config-set, que lo miran ellos
NO_RELOAD = bool(os.environ.get("THEMES_NO_RELOAD"))


# ── Idioma ───────────────────────────────────────────────────

_dict = None  # traducciones del idioma activo; se carga la primera vez que hace falta


def tr(s, *args):
    # Texto en inglés → idioma activo (i18n/<idioma>.json junto a este archivo; sin
    # archivo o sin la clave, inglés). %1, %2... se cambian por args
    global _dict
    if _dict is None:
        _dict = {}
        env = next((v for v in (os.environ.get(k) for k in ("LC_ALL", "LC_MESSAGES", "LANG")) if v), "")
        lang = env.replace(".", "_").replace("@", "_").split("_")[0]
        if lang not in ("", "en", "C", "POSIX"):
            try:
                with open(f"{os.path.dirname(os.path.abspath(__file__))}/i18n/{lang}.json") as f:
                    _dict = json.load(f)
            except (OSError, ValueError):
                pass
    s = _dict.get(s, s)
    for i in range(len(args), 0, -1):  # de mayor a menor: %10 antes que %1
        s = s.replace(f"%{i}", str(args[i - 1]))
    return s


# ── Temas ────────────────────────────────────────────────────

def current_theme():
    # Nombre del tema activo (a dónde apunta el enlace current), o None
    try:
        return os.path.basename(os.readlink(CURRENT))
    except OSError:
        return None


def list_themes():
    # Cada carpeta con un theme.json es un tema
    return sorted(d for d in os.listdir(THEMES)
                  if os.path.isfile(f"{THEMES}/{d}/theme.json") and d != "current")


def load_theme(name="current"):
    with open(f"{THEMES}/{name}/theme.json") as f:
        return json.load(f)


def theme_light():
    # "light": true en el theme.json del tema activo (sin él, oscuro)
    try:
        return bool(load_theme().get("light"))
    except (OSError, ValueError):
        return False


# ── Aumentar contraste (contrast-set) ────────────────────────
# Con el modo activo, theme-set escribe los colores de las terminales (kitty, Ghostty,
# btop, fzf) pasados por boost_contrast() y deja el tema entero así en CONTRAST_THEME,
# que Neovim lee en vez de themes/current/theme.json (nvim/lua/tema/theme.lua).

CONTRAST_STATE = f"{HOME}/.local/state/increased-contrast"
CONTRAST_THEME = f"{HOME}/.local/state/increased-contrast.json"
CONTRAST_MIN = 4.5   # contraste mínimo de cada color contra el fondo (WCAG AA)
CONTRAST_BG = 0.3    # cuánto se acerca el fondo al negro (al blanco en los claros)
CONTRAST_FG = 0.5    # cuánto se acerca el texto al blanco (al negro en los claros)


def contrast_on():
    return read_state(CONTRAST_STATE) == "1"


def rgb(hexcolor):
    h = hexcolor.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def mix(a, b, k):
    # Color entre a y b (k = 0 → a, k = 1 → b); conserva el alfa de a si lo tiene
    out = "#" + "".join(f"{round(x + (y - x) * k):02x}" for x, y in zip(rgb(a), rgb(b)))
    return out + a.lstrip("#")[6:8]


def _lum(h):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _ratio(a, b):
    la, lb = sorted((_lum(a), _lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def _legible(c, bg, ink):
    # Acerca c a ink (blanco o negro) lo justo para llegar a CONTRAST_MIN contra bg
    k = 0.0
    while _ratio(mix(c, ink, k), bg) < CONTRAST_MIN and k < 1:
        k = min(1.0, k + 0.05)
    return mix(c, ink, k)


def boost_contrast(t):
    # Copia del tema con el fondo de la terminal más oscuro (más claro en los temas
    # claros), el texto más marcado y cada color ANSI, de sintaxis de Neovim y de texto
    # de ui con contraste mínimo contra ese fondo. Los que ya se leen bien no cambian.
    # No se tocan colors[0], [7] ni [15]: el negro y los blancos ANSI de cada paleta
    # (en los claros, alguno es del color del fondo a propósito).
    t = json.loads(json.dumps(t))
    light = bool(t.get("light"))
    edge, ink = ("#ffffff", "#000000") if light else ("#000000", "#ffffff")
    term = t["term"]
    bg = term["background"] = mix(term["background"], edge, CONTRAST_BG)
    term["foreground"] = mix(term["foreground"], ink, CONTRAST_FG)
    term["colors"] = [c if i in (0, 7, 15) else _legible(c, bg, ink) for i, c in enumerate(term["colors"])]
    ui = t.get("ui", {})
    if "fg" in ui:
        ui["fg"] = mix(ui["fg"], ink, CONTRAST_FG)
    for k in ("muted", "accent", "accent2", "ok", "red", "yellow", "cyan"):
        if k in ui:
            ui[k] = _legible(ui[k], bg, ink)
    # De nvimColors.ui solo las de texto (panel, sel, visual... son fondos)
    nv = t.get("nvimColors", {})
    text = ("nontext", "special", "muted", "accent", "accent2", "red", "yellow",
            "ok", "info", "hint")
    for group, keys in ((nv.get("syn", {}), None), (nv.get("ui", {}), text)):
        for k, c in group.items():
            if keys is None or k in keys:
                group[k] = _legible(c, bg, ink)
    return t


def saved_profile():
    # Lo que hay en ~/.local/state/desktop-profile, o None si no hay archivo
    return read_state(PROFILE_STATE)


# ── Archivos ─────────────────────────────────────────────────

def read_state(path):
    # Contenido de un archivo de estado (~/.local/state/...), o None si no existe
    try:
        return open(path).read().strip()
    except OSError:
        return None


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def write_atomic(path, text):
    # Se escribe aparte y se cambia de golpe: quien lo lea nunca lo ve a medias
    tmp = path + ".tmp"
    write(tmp, text)
    os.replace(tmp, path)


def load_script(name):
    # Carga otro script de esta carpeta (sin .py) como módulo, sin __pycache__
    sys.dont_write_bytecode = True
    mod = name.replace("-", "_")
    loader = SourceFileLoader(mod, f"{THEMES}/{name}")
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(mod, loader))
    loader.exec_module(module)
    return module


# ── Avisos ───────────────────────────────────────────────────

def run_quiet(cmd):
    if not NO_RELOAD:
        subprocess.run(cmd, **QUIET)


def qs_theme_reload():
    # Quickshell relee theme.json y pide el fondo a background-set
    run_quiet(["qs", "ipc", "call", "theme", "reload"])


def reload_terminals():
    run_quiet(["pkill", "-USR1", "-x", "kitty"])  # kitty relee su config
    run_quiet(["pkill", "-USR2", "-x", "ghostty"])  # ghostty también (SIGUSR2)


def notify(app, title, body):
    run_quiet(["notify-send", "-a", app, title, body])


if __name__ == "__main__" and sys.argv[1:2] == ["tr"] and len(sys.argv) > 2:
    print(tr(*sys.argv[2:]), end="")
