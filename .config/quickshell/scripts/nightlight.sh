#!/usr/bin/env bash
# Luz nocturna para la barra de Quickshell, habla con hyprsunset por IPC
#   sin argumentos: estado en JSON: class ("on" | "off" | "unavailable"),
#                   temperature y next (epoch del próximo cambio del horario).
#                   Los textos los pone (y traduce) Quickshell
#   toggle:         activa/desactiva
#   up / down:      más fría / más cálida
#
# hyprsunset no deja consultar si está en "identity" (apagado), así que el
# apagado manual se guarda en $state. Vale hasta el siguiente cambio del
# horario de ~/.config/hypr/hyprsunset.conf, que manda sobre el botón.

warm=4000
step=250
state="${XDG_RUNTIME_DIR:-/tmp}/nightlight-off"
conf="$HOME/.config/hypr/hyprsunset.conf"

# Quickshell (services/NightLight.qml) vuelve a leer el estado tras cada acción

current() {
    hyprctl hyprsunset temperature 2>/dev/null | grep -oE '^[0-9]+$'
}

# Epoch del último y del próximo cambio de perfil del horario: "último próximo"
profile_changes() {
    local now last=0 next=0 t ts day
    now=$(date +%s)
    for t in $(sed -nE 's/^\s*time\s*=\s*([0-9]{1,2}:[0-9]{2}).*/\1/p' "$conf"); do
        for day in yesterday today tomorrow; do
            ts=$(date -d "$day $t" +%s)
            (( ts <= now && ts > last )) && last=$ts
            (( ts > now && (next == 0 || ts < next) )) && next=$ts
        done
    done
    echo "$last $next"
}

is_on() {
    local t=$1 changes
    [ "$t" -lt 6000 ] || return 1
    [ -f "$state" ] || return 0
    read -ra changes < <(profile_changes)
    (( $(stat -c %Y "$state") <= changes[0] ))
}

t=$(current)

case "$1" in
    toggle)
        [ -n "$t" ] || exit 0
        if is_on "$t"; then
            hyprctl hyprsunset identity >/dev/null
            touch "$state"
        else
            hyprctl hyprsunset temperature "$warm" >/dev/null
            rm -f "$state"
        fi ;;
    up|down)
        [ -n "$t" ] && is_on "$t" || exit 0
        [ "$1" = up ] && t=$((t + step)) || t=$((t - step))
        t=$(( t < 2500 ? 2500 : t > 5750 ? 5750 : t ))
        hyprctl hyprsunset temperature "$t" >/dev/null ;;
    *)
        if [ -z "$t" ]; then class=unavailable
        elif is_on "$t"; then class=on
        else class=off
        fi
        read -ra changes < <(profile_changes)
        echo "{\"class\": \"$class\", \"temperature\": ${t:-0}, \"next\": ${changes[1]}}" ;;
esac
