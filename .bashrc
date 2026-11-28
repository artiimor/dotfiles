#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# bat and fzf colors matching kitty (fzf comes from the active theme: ~/.config/themes)
export BAT_THEME="ansi"
[ -f ~/.config/themes/current-env.sh ] && . ~/.config/themes/current-env.sh

# Prompt: starship (config in ~/.config/starship.toml)
command -v starship >/dev/null && eval "$(starship init bash)"

# Large history, no duplicates and shared between terminals
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend cdspell
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# ls with git (eza) and cat with colors (bat)
if command -v eza >/dev/null; then
    alias ls='eza --group-directories-first'
    alias ll='eza -l --group-directories-first --git --no-user --time-style=relative'
    alias la='ll -a'
    alias tree='eza --tree --level=2'
fi
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'

# fzf: Ctrl+R history, Ctrl+T files, Alt+C folders (active theme colors)
command -v fzf >/dev/null && eval "$(fzf --bash)"

# Neovim: `nvim` is the sober mini.nvim config; `lazyvim` opens the LazyVim one
lazyvim() { NVIM_APPNAME=nvim-lazyvim nvim "$@"; }
