# Quickshell IPC: every `qs ipc call <target> <function>` in the repo has its
# `IpcHandler { target: "<target>" ... function <function>(` in the config it goes to.
# With `-p .../macshell` it goes to macshell (.config/quickshell/macshell); otherwise, to the root one
# (.config/quickshell without macshell).
#
# Which calls are found (regex, no real parsing; comment lines are skipped):
#   - Text: `qs [-p <path>] ipc call <target> <function>` (Lua, hypr conf, bash, QML).
#   - Lists: ["qs", "-p", Quickshell.shellDir + "/macshell", "ipc", "call", ...] (QML and
#     Python): their literals are joined with spaces and checked as text.
#   - binds.lua: `shellCmd("<target> <function>", "<own command>")` and `macshell .. "<target> <function>"`
#     go to macshell (the own command is found by the text case).
# Calls whose function is a variable are skipped (e.g. `"launcher", mode`).
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
    # (file, macshell?, target, function) of each call
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
    # target -> functions of the IpcHandlers in those QML files (block by brace counting)
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
    # If the regex breaks, don't pass without checking anything
    assert len(found) > 20, found
    assert any(m for _, m, _, _ in found) and not all(m for _, m, _, _ in found)
    bad = [f"{p.relative_to(REPO)}: {'macshell ' if m else ''}{t} {f}"
           for p, m, t, f in found if f not in (mac if m else root).get(t, ())]
    assert not bad, "llamadas IPC sin IpcHandler:\n" + "\n".join(bad)
