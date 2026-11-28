# Helpers shared by the bash scripts (install.sh, bin/wasdjy-migrate, bin/wasdjy-update).
# Sourced with its absolute path: . "$REPO/lib/wasdjy.sh"

# Messages are translated with themelib.py, next to this file: t "Text %1" arg.
# Without python3, in English with the %N replaced here
t() {
	python3 "${BASH_SOURCE[0]%/*}/themelib.py" tr "$@" 2>/dev/null && return
	local s="$1" i=1 a
	shift
	for a; do s="${s//"%$i"/"$a"}" i=$((i + 1)); done
	printf '%s' "$s"
}

bold=$'\e[1m' dim=$'\e[2m' accent=$'\e[35m' red=$'\e[31m' reset=$'\e[0m'

step() { printf '\n%s==>%s %s%s%s\n' "$accent" "$reset" "$bold" "$*" "$reset"; }
info() { printf '    %s%s%s\n' "$dim" "$*" "$reset"; }
warn() { printf '    %s!%s %s\n' "$red" "$reset" "$*"; }

# ask "question" -> 0 if yes (Enter = yes). YES=1 (--yes) answers yes without asking
ask() {
	((${YES:-0})) && return 0
	local r
	read -rp "    $1 $(t "[Y/n]") " r
	[[ -z "$r" || "$r" =~ ^[sSyY] ]]
}
