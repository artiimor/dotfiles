# Common test fixtures: repo paths and theme list.
import json
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
CONFIG = REPO / ".config"
THEMES_DIR = CONFIG / "themes"
# current is a symlink to the active theme: it isn't one more theme
THEMES = sorted(p.parent.name for p in THEMES_DIR.glob("*/theme.json") if not p.parent.is_symlink())

# Same mapping as `groups` in nvim/colors/tema.lua: nvimColors.syn key -> groups
SYN_GROUPS = {
    "string": "String", "number": "Number", "constant": "Constant", "identifier": "Identifier",
    "parameter": "@variable.parameter", "fun": "Function", "statement": "Statement",
    "keyword": "Keyword", "operator": "Operator", "preproc": "PreProc", "type": "Type",
    "regex": "@string.regexp", "punct": "Delimiter", "comment": "Comment",
    "special1": "Special", "special2": "SpecialChar", "special3": "@punctuation.special",
}


def load_theme(name):
    return json.loads((THEMES_DIR / name / "theme.json").read_text())


@pytest.fixture(params=THEMES)
def theme(request):
    # (name, theme.json content) of each theme
    return request.param, load_theme(request.param)
