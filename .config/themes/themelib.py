# Lo común a theme-set, config-set, background-set y font-set: rutas, tema actual, perfil
# guardado, escritura de archivos y avisos a Quickshell. No es un tema (no tiene
# theme.json) ni un script: lo importan ellos, que se ejecutan desde esta
# carpeta (sys.path[0]) y ponen antes sys.dont_write_bytecode = True para que no
# aparezca __pycache__ aquí.

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
    subprocess.run(cmd, **QUIET)


def qs_theme_reload():
    # Quickshell relee theme.json y pide el fondo a background-set
    run_quiet(["qs", "ipc", "call", "theme", "reload"])


def reload_terminals():
    run_quiet(["pkill", "-USR1", "-x", "kitty"])  # kitty relee su config
    run_quiet(["pkill", "-USR2", "-x", "ghostty"])  # ghostty también (SIGUSR2)


def notify(app, title, body):
    run_quiet(["notify-send", "-a", app, title, body])
