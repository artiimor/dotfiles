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
# con un Pepe al azar de ~/.config/fastfetch/pepe-*.txt (los genera pepe.py)
if command -v fastfetch >/dev/null; then
    pepes=(~/.config/fastfetch/pepe-*.txt)
    fastfetch --logo "${pepes[RANDOM % ${#pepes[@]}]}" --logo-type file-raw
    unset pepes
fi
