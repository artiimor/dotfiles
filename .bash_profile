#
# ~/.bash_profile
#

# login bash doesn't read ~/.profile if this file exists: it is sourced by hand
# (the cargo PATH is there) and then the interactive config
[[ -f ~/.profile ]] && . ~/.profile
[[ -f ~/.bashrc ]] && . ~/.bashrc
