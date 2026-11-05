#!/usr/bin/env bash
# Luz nocturna para la barra de Quickshell, habla con hyprsunset por IPC
#   sin argumentos: estado en JSON
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

current() {
    hyprctl hyprsunset temperature 2>/dev/null | grep -oE '^[0-9]+$'
}

# Epoch del último cambio de perfil del horario (hoy o ayer)
last_profile_change() {
    local now last=0 t ts
    now=$(date +%s)
    for t in $(sed -nE 's/^\s*time\s*=\s*([0-9]{1,2}:[0-9]{2}).*/\1/p' "$conf"); do
        for day in today yesterday; do
            ts=$(date -d "$day $t" +%s)
            (( ts <= now && ts > last )) && last=$ts
        done
    done
    echo "$last"
}

is_on() {
    local t=$1
    [ "$t" -lt 6000 ] || return 1
    [ -f "$state" ] && (( $(stat -c %Y "$state") > $(last_profile_change) )) && return 1
    return 0
}

# Quickshell vuelve a leer el estado tras cada acción, no hace falta avisar
refresh() { :; }

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
        fi
        refresh ;;
    up|down)
        [ -n "$t" ] && is_on "$t" || exit 0
        [ "$1" = up ] && t=$((t + step)) || t=$((t - step))
        t=$(( t < 2500 ? 2500 : t > 5750 ? 5750 : t ))
        hyprctl hyprsunset temperature "$t" >/dev/null
        refresh ;;
    *)
        if [ -z "$t" ]; then
            echo '{"text": "󰖙", "class": "unavailable", "tooltip": "hyprsunset no está en marcha"}'
        elif is_on "$t"; then
            echo "{\"text\": \"󰖔\", \"class\": \"on\", \"tooltip\": \"Luz nocturna: ${t} K\\nRueda: ajustar · Clic: apagar\"}"
        else
            echo '{"text": "󰖙", "class": "off", "tooltip": "Luz nocturna apagada\nClic: encender"}'
        fi ;;
esac
