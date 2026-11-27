#!/usr/bin/env bash
# Tests del repo: linters + pytest. Uso: tests/run.sh
# En local se salta (con aviso) lo que no esté instalado; en CI (CI=true) eso es un fallo.
cd "$(dirname "$0")/.." || exit 1

QMLLINT=${QMLLINT:-/usr/lib/qt6/bin/qmllint}
results=()
failed=0

# check <nombre> <herramienta> <orden...>: ejecuta la orden y apunta el resultado
check() {
	local name=$1 tool=$2
	shift 2
	if ! command -v "$tool" >/dev/null; then
		if [[ $CI == true ]]; then
			results+=("FAIL  $name ($tool not found)")
			failed=1
		else
			results+=("SKIP  $name ($tool not found)")
		fi
		return
	fi
	echo "== $name"
	if "$@"; then
		results+=("OK    $name")
	else
		results+=("FAIL  $name")
		failed=1
	fi
}

# each <orden...> -- <archivos...>: la orden con cada archivo, falla si falla alguno
each() {
	local cmd=() f rc=0
	while [[ $1 != -- ]]; do cmd+=("$1"); shift; done
	shift
	for f; do "${cmd[@]}" "$f" >/dev/null || rc=1; done
	return "$rc"
}

# Scripts de shell: los de la raíz, el entorno de uwsm y los que tienen shebang de sh/bash
shells=(install.sh .bashrc .bash_profile .profile .config/uwsm/env)
while IFS= read -r -d '' f; do
	IFS= read -r line <"$f"
	[[ $line =~ ^#!.*[/\ ](ba)?sh($|\ ) ]] && shells+=("$f")
done < <(find .config .local system tests -type f -print0)

mapfile -t hypr_lua < <(find .config/hypr -name '*.lua')
mapfile -t nvim_lua < <(find .config/nvim .config/nvim-lazyvim -name '*.lua')
mapfile -t qml < <(find .config/quickshell -name '*.qml')

check shellcheck shellcheck shellcheck -S warning "${shells[@]}"
check "lua syntax (hypr)" luac luac -p "${hypr_lua[@]}"
check "lua syntax (nvim)" luajit each luajit -bl -- "${nvim_lua[@]}"
check luacheck luacheck luacheck -q "${hypr_lua[@]}" "${nvim_lua[@]}"
# qmllint solo mira la sintaxis: sin Quickshell ni `import qs` resueltos, el resto es ruido
check qmllint "$QMLLINT" "$QMLLINT" --only-explicit-categories "${qml[@]}"
check pytest pytest env PYTHONDONTWRITEBYTECODE=1 pytest -q -p no:cacheprovider tests

echo
printf '%s\n' "${results[@]}"
exit $failed
