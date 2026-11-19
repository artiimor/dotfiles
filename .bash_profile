#
# ~/.bash_profile
#

# bash de login no lee ~/.profile si existe este archivo: se carga a mano
# (ahí está el PATH de cargo) y después la config interactiva
[[ -f ~/.profile ]] && . ~/.profile
[[ -f ~/.bashrc ]] && . ~/.bashrc
