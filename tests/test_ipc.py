# IPC de Quickshell: cada `qs ipc call <target> <función>` del repo tiene su
# `IpcHandler { target: "<target>" ... function <función>(` en la config a la que va.
# Con `-p .../macshell` va a macshell (.config/quickshell/macshell); si no, a la raíz
# (.config/quickshell sin macshell).
#
# Qué llamadas se encuentran (regex, sin parsear de verdad; se saltan las líneas de comentario):
#   - Texto: `qs [-p <ruta>] ipc call <target> <función>` (Lua, conf de hypr, bash, QML).
#   - Listas: ["qs", "-p", Quickshell.shellDir + "/macshell", "ipc", "call", ...] (QML y
#     Python): se juntan sus literales con espacios y se mira como texto.
#   - binds.lua: `shellCmd("<target> <función>", "<orden propia>")` y `macshell .. "<target> <función>"`
#     van a macshell (la orden propia la encuentra el caso de texto).
# Se saltan las llamadas cuya función es una variable (p. ej. `"launcher", mode`).
import re

from conftest import CONFIG, REPO

QS = CONFIG / "quickshell"
MAC = QS / "macshell"

FILES = sorted({*CONFIG.glob("hypr/**/*.lua"), *CONFIG.glob("hypr/*.conf"), *QS.glob("**/*.qml"),
                *(p for p in (CONFIG / "themes").iterdir() if p.is_file() and p.suffix != ".md"),
                *(QS / "scripts").iterdir()})

CALL = re.compile(r"\bqs(?: -p (\S+))? ipc call (\w+) (\w+)")
LIST = re.compile(r'\[\s*"qs"\s*,[^\]]*\]')
LUA_MAC = re.compile(r'(?:shellCmd\(|\bmacshell \.\. )"(\w+) (\w+)')


def calls():
    # (archivo, macshell?, target, función) de cada llamada
    out = []
    for path in FILES:
        text = "\n".join(l for l in path.read_text().splitlines()
                         if not l.lstrip().startswith(("//", "#", "--")))
        cmds = [text] + [" ".join(re.findall(r'"([^"]*)"', m)) for m in LIST.findall(text)]
        for cmd in cmds:
            out += [(path, "macshell" in (p or ""), t, f) for p, t, f in CALL.findall(cmd)]
        out += [(path, True, t, f) for t, f in LUA_MAC.findall(text)]
    return out


def handlers(qmls):
    # target -> funciones de los IpcHandler de esos QML (bloque por conteo de llaves)
    out = {}
    for path in qmls:
        text = path.read_text()
        for m in re.finditer(r"\bIpcHandler\s*\{", text):
            depth, i = 0, m.end() - 1
            for i in range(i, len(text)):
                depth += {"{": 1, "}": -1}.get(text[i], 0)
                if depth == 0:
                    break
            block = text[m.end():i]
            target = re.search(r'target:\s*"(\w+)"', block).group(1)
            out.setdefault(target, set()).update(re.findall(r"\bfunction (\w+)\s*\(", block))
    return out


def test_ipc_calls():
    mac = handlers(MAC.glob("**/*.qml"))
    root = handlers(p for p in QS.glob("**/*.qml") if MAC not in p.parents)
    found = calls()
    # Si la regex se rompe, que no pase sin mirar nada
    assert len(found) > 20, found
    assert any(m for _, m, _, _ in found) and not all(m for _, m, _, _ in found)
    bad = [f"{p.relative_to(REPO)}: {'macshell ' if m else ''}{t} {f}"
           for p, m, t, f in found if f not in (mac if m else root).get(t, ())]
    assert not bad, "llamadas IPC sin IpcHandler:\n" + "\n".join(bad)
