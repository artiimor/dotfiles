if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
# wasdjy scripts (wasdjy-theme, wasdjy-config...) in the PATH for login shells (TTY, ssh);
# the Hyprland session gets it from ~/.config/uwsm/env
case ":$PATH:" in *":$HOME/.local/share/wasdjy/bin:"*) ;; *) PATH="$HOME/.local/share/wasdjy/bin:$PATH" ;; esac
export PATH
