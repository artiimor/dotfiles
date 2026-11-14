#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
. "$HOME/.cargo/env"

# Colores de bat y fzf a juego con kitty (fzf sale del tema activo: ~/.config/themes)
export BAT_THEME="ansi"
[ -f ~/.config/themes/current-env.sh ] && . ~/.config/themes/current-env.sh

# Prompt: starship (config en ~/.config/starship.toml)
command -v starship >/dev/null && eval "$(starship init bash)"

# Info del sistema al abrir la terminal (config en ~/.config/fastfetch/config.jsonc)
# con un Pepe ASCII al azar (pepe-*.txt, los genera pepe.py; theme-set los tiñe en themed/)
if command -v fastfetch >/dev/null; then
    pepes=(~/.config/fastfetch/pepe-*.txt)
    pepe=$(basename "${pepes[RANDOM % ${#pepes[@]}]}" .txt)
    unset pepes
    logo=~/.config/fastfetch/themed/$pepe.txt
    [ -f "$logo" ] || logo=~/.config/fastfetch/$pepe.txt
    if [ "$pepe" = pepe-mago ]; then
        # el mago es alto: los "break" de la config bajan la info a la altura de la túnica
        fastfetch --logo "$logo" --logo-type file-raw
    else
        cfg="${XDG_RUNTIME_DIR:-/tmp}/fastfetch-pepe.jsonc"
        sed '/"break", "break"/d' ~/.config/fastfetch/config.jsonc > "$cfg"
        fastfetch -c "$cfg" --logo "$logo" --logo-type file-raw
        unset cfg
    fi
    unset pepe logo
fi
