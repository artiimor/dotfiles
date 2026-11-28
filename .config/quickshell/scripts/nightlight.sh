#!/usr/bin/env bash
# Night light for the Quickshell bar, talks to hyprsunset over IPC
#   no arguments:   state as JSON: class ("on" | "off" | "unavailable"),
#                   temperature and next (epoch of the next schedule change).
#                   The texts are set (and translated) by Quickshell
#   toggle:         turn on/off
#   up / down:      cooler / warmer
#
# hyprsunset can't be asked whether it is in "identity" (off), so
# turning it off by hand is saved in $state. It lasts until the next change of the
# schedule in ~/.config/hypr/hyprsunset.conf, which overrides the button.

warm=4000
step=250
state="${XDG_RUNTIME_DIR:-/tmp}/nightlight-off"
conf="$HOME/.config/hypr/hyprsunset.conf"

# Quickshell (services/NightLight.qml) reads the state again after each action

current() {
    hyprctl hyprsunset temperature 2>/dev/null | grep -oE '^[0-9]+$'
}

# Epoch of the last and next profile change of the schedule: "last next"
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
