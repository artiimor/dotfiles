#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi

# Colores de bat y fzf a juego con kitty (fzf sale del tema activo: ~/.config/themes)
export BAT_THEME="ansi"
[ -f ~/.config/themes/current-env.sh ] && . ~/.config/themes/current-env.sh

# Prompt: starship (config en ~/.config/starship.toml)
command -v starship >/dev/null && eval "$(starship init bash)"

# Historial grande, sin duplicados y compartido entre terminales
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend cdspell
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# ls con git (eza) y cat con colores (bat)
if command -v eza >/dev/null; then
    alias ls='eza --group-directories-first'
    alias ll='eza -l --group-directories-first --git --no-user --time-style=relative'
    alias la='ll -a'
    alias tree='eza --tree --level=2'
fi
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'

# fzf: Ctrl+R historial, Ctrl+T archivos, Alt+C carpetas (colores del tema activo)
command -v fzf >/dev/null && eval "$(fzf --bash)"
