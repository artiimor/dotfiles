# Languages: the i18n/*.json files are flat JSON English → translation, with the same
# %N placeholders, and every text translated in the code has its entry in es.json.
import ast
import json
import re

import pytest

from conftest import BIN, CONFIG, LIB, REPO

QS = CONFIG / "quickshell"
MAC = QS / "macshell"
I18N_DIRS = [QS / "i18n", MAC / "i18n", LIB / "i18n"]
JSONS = sorted(p for d in I18N_DIRS for p in d.glob("*.json"))

# Double-quoted literal, with escapes (\n, \")
STR = r'"((?:[^"\\\n]|\\.)*)"'


def rel(p):
    return str(p.relative_to(REPO))


def load(path):
    # Like json.load, but fails on duplicate keys (json keeps the last one)
    def pairs(items):
        keys = [k for k, _ in items]
        dup = {k for k in keys if keys.count(k) > 1}
        assert not dup, f"{rel(path)}: claves repetidas {sorted(dup)}"
        return dict(items)
    return json.loads(path.read_text(), object_pairs_hook=pairs)


def lines(path, comment):
    # The file without its comment lines (e.g. the user.lua examples)
    return "\n".join(l for l in path.read_text().splitlines() if not l.lstrip().startswith(comment))


# ── Texts translated in the code ──────────────────────

def qml_texts(root, skip=None):
    # I18n.tr("...") literals in the root QML files (without the skip folder)
    return {json.loads(f'"{s}"') for f in root.rglob("*.qml") if not (skip and skip in f.parents)
            for s in re.findall(r"I18n\.tr\(" + STR, f.read_text())}


def bind_texts():
    # Hyprland bind descriptions (translated by the root Launcher with I18n.tr):
    # the "description = ..." literals and the last argument of bindDigits(..., end, "X")
    # and resizeBind("H", -50, 0, "X"), which pass it through the desc variable
    out = set()
    for f in (CONFIG / "hypr/config").glob("*.lua"):
        text = lines(f, "--")
        for expr in re.findall(r"description = ([^}\n]*)", text):
            out |= {json.loads(f'"{s}"') for s in re.findall(STR, expr)}
        out |= {json.loads(f'"{s}"') for s in re.findall(r"(?:end|\d), " + STR + r"\)\s*$", text, re.M)}
    return out


def is_python(path):
    return path.read_text().startswith("#!/usr/bin/env python3")


def python_texts():
    # tr("...") with a literal as first argument in the Python bin/ scripts and themelib.py
    out = set()
    for path in [*(p for p in sorted(BIN.glob("wasdjy-*")) if is_python(p)), LIB / "themelib.py"]:
        for node in ast.walk(ast.parse(path.read_text())):
            if (isinstance(node, ast.Call) and getattr(node.func, "id", None) == "tr"
                    and node.args and isinstance(node.args[0], ast.Constant)):
                out.add(node.args[0].value)
    return out


def bash_texts():
    # t "Text %1" arg in install.sh, lib/wasdjy.sh, the bash bin/ scripts and quickshell/scripts
    # (t calls themelib.py tr); also $(t No) without quotes. Those with variables ($1...) are skipped
    out = set()
    bash_bin = [p for p in sorted(BIN.glob("wasdjy-*")) if not is_python(p)]
    for f in [REPO / "install.sh", LIB / "wasdjy.sh", *bash_bin, *(QS / "scripts").iterdir()]:
        for s, word in re.findall(r"(?<![\w$-])t (?:" + STR + r"|(\w+)\))", lines(f, "#")):
            s = re.sub(r'\\(["\\$`])', r"\1", s) or word
            if "$" not in s:
                out.add(s)
    return out


CASES = {
    "quickshell": (QS / "i18n/es.json", qml_texts(QS, MAC) | bind_texts()),
    "macshell": (MAC / "i18n/es.json", qml_texts(MAC)),
    "themes": (LIB / "i18n/es.json", python_texts() | bash_texts()),
}


# ── Tests ────────────────────────────────────────────────────

@pytest.mark.parametrize("path", JSONS, ids=rel)
def test_json_plano(path):
    d = load(path)
    bad = [k for k, v in d.items() if not isinstance(k, str) or not isinstance(v, str)]
    assert not bad, f"{rel(path)}: valores que no son texto {bad}"
    empty = [k for k, v in d.items() if not v.strip()]
    assert not empty, f"{rel(path)}: traducciones vacías {empty}"


@pytest.mark.parametrize("path", JSONS, ids=rel)
def test_marcadores(path):
    marks = lambda s: sorted(set(re.findall(r"%\d+", s)))
    bad = [k for k, v in load(path).items() if marks(k) != marks(v)]
    assert not bad, f"{rel(path)}: los %N no coinciden en {bad}"


def test_i18n_qml_identicos():
    assert (QS / "I18n.qml").read_text() == (MAC / "I18n.qml").read_text(), \
        "quickshell/I18n.qml y macshell/I18n.qml son distintos"


@pytest.mark.parametrize("case", CASES)
def test_textos_traducidos(case):
    path, texts = CASES[case]
    missing = sorted(texts - set(load(path)))
    assert not missing, f"{rel(path)}: faltan {missing}"


@pytest.mark.parametrize("case", CASES)
def test_sin_huerfanas(case):
    path, texts = CASES[case]
    orphans = sorted(set(load(path)) - texts)
    assert not orphans, f"{rel(path)}: entradas que no usa nadie {orphans}"
