#!/usr/bin/env bash
# Instala este escritorio sobre un CachyOS recién instalado.
#
#   git clone https://github.com/artiimor/dotfiles.git ~/dotfiles
#   ~/dotfiles/install.sh            pregunta antes de cada paso
#   ~/dotfiles/install.sh --yes      lo hace todo sin preguntar
#
# Pasos (cada uno se puede saltar):
#   1. Paquetes del escritorio (pacman) y los de AUR (bzmenu) con makepkg
#   2. Apps extra (Firefox, Brave, Spotify, Discord, Proton...)
#   3. Dotfiles: .config, .bashrc, webapps -> ~ (lo que pisa va a ~/.dotfiles-old/<fecha>) y bash como shell
#   4. Tema de colores (theme-set) y perfil Mac/Default (config-set)
#   5. Plugin hyprbars con el parche del modo escritorio (y quita los botones propios de GTK/Brave)
#   6. Sistema (sudo): greetd + ReGreet, Plymouth "canalla", keyd (ThinkPad), servicios
#
# Ejecútalo como tu usuario, no como root: pide sudo cuando lo necesita.
# Se puede repetir sin miedo: pacman usa --needed y los archivos se sobrescriben.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="grafito"
YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && YES=1

# ---------------------------------------------------------------- paquetes

# Escritorio: Hyprland + Quickshell y lo que usan los binds y la barra
DESKTOP=(
	hyprland quickshell uwsm xdg-desktop-portal-hyprland
	hypridle hyprlock hyprsunset hyprshot hyprpicker grim slurp
	cliphist wl-clipboard brightnessctl playerctl ddcutil
	pipewire-pulse wireplumber pavucontrol power-profiles-daemon upower
	networkmanager networkmanager-dmenu bluez bluez-utils
	gnome-keyring seahorse
	dolphin kde-cli-tools ffmpegthumbnailer qview gnome-calculator gnome-text-editor swash
	qt6ct nwg-look adw-gtk-theme papirus-icon-theme
)
# Terminal, shell y Neovim
TERMINAL=(
	ghostty kitty starship btop fastfetch bash-completion
	neovim lazygit ripgrep tree-sitter-cli nodejs npm micro
	python python-defusedxml git base-devel rsync
)
FONTS=(
	ttf-jetbrains-mono-nerd otf-geist-mono-nerd inter-font cantarell-fonts
	noto-fonts noto-fonts-emoji noto-fonts-cjk
)
# Login y arranque
SYSTEM=(greetd greetd-regreet cage plymouth keyd)
# No están en los repos: se compilan desde AUR
AUR=(bzmenu)
# Opcionales
APPS=(firefox brave-bin spotify-launcher discord proton-pass proton-vpn-gtk-app claude-code github-cli)

# ---------------------------------------------------------------- utilidades

bold=$'\e[1m' dim=$'\e[2m' accent=$'\e[35m' red=$'\e[31m' reset=$'\e[0m'

step() { printf '\n%s==>%s %s%s%s\n' "$accent" "$reset" "$bold" "$*" "$reset"; }
info() { printf '    %s%s%s\n' "$dim" "$*" "$reset"; }
warn() { printf '    %s!%s %s\n' "$red" "$reset" "$*"; }

# ask "pregunta" -> 0 si sí (Enter = sí)
ask() {
	((YES)) && return 0
	local r
	read -rp "    $1 [S/n] " r
	[[ -z "$r" || "$r" =~ ^[sSyY] ]]
}

if [[ $EUID -eq 0 ]]; then
	echo "Ejecútalo como tu usuario, no como root." >&2
	exit 1
fi
if ! command -v pacman >/dev/null; then
	echo "Esto es para CachyOS/Arch (no hay pacman)." >&2
	exit 1
fi

BACKUP="$HOME/.dotfiles-old/$(date +%Y%m%d-%H%M%S)"

# Copia src -> dst; lo que se sobrescriba se guarda en $BACKUP con la misma ruta
copy_tree() {
	local src="$1" dst="$2" rel="${2#"$HOME"/}"
	mkdir -p "$dst"
	rsync -a --backup --backup-dir="$BACKUP/$rel" "$src/" "$dst/"
}

# Las rutas absolutas de la config llevan /home/morci: se cambian por tu $HOME
fix_home() {
	[[ "$HOME" == "/home/morci" ]] && return 0
	grep -rlZ '/home/morci' "$@" 2>/dev/null | xargs -0r sed -i "s|/home/morci|$HOME|g"
}

aur_install() {
	local pkg dir
	for pkg in "$@"; do
		if pacman -Qq "$pkg" &>/dev/null; then
			info "$pkg ya está instalado"
			continue
		fi
		dir="$(mktemp -d)"
		git clone --depth 1 "https://aur.archlinux.org/$pkg.git" "$dir/$pkg"
		(cd "$dir/$pkg" && makepkg -si --needed --noconfirm)
		rm -rf "$dir"
	done
}

# ---------------------------------------------------------------- 1. paquetes

step "1. Paquetes del escritorio"
info "${#DESKTOP[@]} de escritorio, ${#TERMINAL[@]} de terminal, ${#FONTS[@]} fuentes, ${#SYSTEM[@]} de login/arranque, AUR: ${AUR[*]}"
if ask "¿Instalarlos?"; then
	sudo pacman -Syu --needed --noconfirm "${DESKTOP[@]}" "${TERMINAL[@]}" "${FONTS[@]}" "${SYSTEM[@]}"
	aur_install "${AUR[@]}"
fi

# ---------------------------------------------------------------- 2. apps

step "2. Apps extra"
info "${APPS[*]}"
if ask "¿Instalarlas?"; then
	sudo pacman -S --needed --noconfirm "${APPS[@]}" || warn "alguna no se pudo instalar, sigo"
fi

# ---------------------------------------------------------------- 3. dotfiles

step "3. Dotfiles"
info "$REPO/.config -> ~/.config, .bashrc, .bash_profile, .profile, webapps"
info "lo que se sobrescriba se guarda en $BACKUP"
if ask "¿Copiarlos?"; then
	copy_tree "$REPO/.config" "$HOME/.config"
	copy_tree "$REPO/.local/share/applications" "$HOME/.local/share/applications"
	for f in .bashrc .bash_profile .profile; do
		if [[ -f "$HOME/$f" ]] && ! cmp -s "$REPO/$f" "$HOME/$f"; then
			mkdir -p "$BACKUP"
			cp "$HOME/$f" "$BACKUP/$f"
		fi
		cp "$REPO/$f" "$HOME/$f"
	done
	fix_home "$HOME/.config/quickshell" "$HOME/.config/networkmanager-dmenu" \
		"$HOME/.config/ghostty" "$HOME/.local/share/applications"
	chmod +x "$HOME/.config/themes/theme-set" "$HOME/.config/themes/config-set" "$HOME/.config/quickshell/scripts/"* 2>/dev/null || true
	# Cursor por defecto (Adwaita) también para apps X11
	mkdir -p "$HOME/.icons/default"
	printf '[Icon Theme]\nName=Default\nInherits=Adwaita\n' >"$HOME/.icons/default/index.theme"
	xdg-user-dirs-update 2>/dev/null || true
	[[ -d "$BACKUP" ]] && info "copias de lo anterior en $BACKUP"
fi

# CachyOS pone fish de shell por defecto; la config de este repo es la de bash (.bashrc)
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != */bash ]] && ask "¿Usar bash como shell (en vez de fish)?"; then
	sudo chsh -s /bin/bash "$USER"
	info "shell cambiado a bash: se nota al volver a iniciar sesión"
fi

# ---------------------------------------------------------------- 4. tema

step "4. Tema de colores"
if [[ -x "$HOME/.config/themes/theme-set" ]] && ask "¿Aplicar el tema $THEME?"; then
	"$HOME/.config/themes/theme-set" "$THEME" || warn "theme-set falló; repítelo dentro de Hyprland"
fi
# Perfil del escritorio (Super+Shift+T): "mac" si está macshell (repo plasma-mac), si no "default".
# Ajusta iconos GTK/Qt y qt6ct a ese perfil (el repo los trae como en "mac")
if [[ -x "$HOME/.config/themes/config-set" ]]; then
	"$HOME/.config/themes/config-set" --reapply || warn "config-set falló; repítelo dentro de Hyprland"
fi

# ---------------------------------------------------------------- 5. hyprbars

step "5. Barras de título (hyprbars con parche)"
info "se compila con la misma versión que el Hyprland instalado"
if command -v Hyprland >/dev/null && ask "¿Compilar hyprbars?"; then
	ver="$(pacman -Q hyprland | awk '{print $2}' | cut -d- -f1)"
	dir="$(mktemp -d)"
	# hyprland-plugins solo etiqueta algunas versiones (v0.57.0 vale para 0.57.1)
	if git clone https://github.com/hyprwm/hyprland-plugins "$dir/hp" &&
		{ git -C "$dir/hp" checkout -q "v$ver" 2>/dev/null ||
			git -C "$dir/hp" checkout -q "v${ver%.*}.0"; } &&
		git -C "$dir/hp" apply "$REPO/.config/hypr/hyprbars-on-drag-end.patch" \
			"$REPO/.config/hypr/hyprbars-hover-icon.patch" &&
		make -C "$dir/hp/hyprbars" all; then
		mkdir -p "$HOME/.local/lib/hyprland"
		cp "$dir/hp/hyprbars/hyprbars.so" "$HOME/.local/lib/hyprland/"
		info "hyprbars v$ver instalado en ~/.local/lib/hyprland"
	else
		warn "no se pudo compilar (¿no hay tag v$ver en hyprland-plugins?). Sin él todo funciona, solo que sin barras de título."
	fi
	rm -rf "$dir"
fi

# Los botones de cerrar/minimizar/maximizar los pone hyprbars (estilo macOS):
# se quitan los que dibujan las propias apps para que no salgan dos veces
if ask "¿Quitar los botones de ventana propios de GTK y Brave (se quedan solo los de hyprbars)?"; then
	# GTK 4 / libadwaita lo lee de aquí; GTK 3 de gtk-3.0/settings.ini (paso 3)
	gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:' 2>/dev/null || true
	# Brave: "Usar la barra de título y los bordes del sistema" (brave://settings/appearance).
	# Con Brave abierto el cambio se pierde al cerrarlo, así que solo se toca si está cerrado
	prefs="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"
	if pgrep -x brave >/dev/null; then
		warn "Brave está abierto: ciérralo y repite este paso, o actívalo en brave://settings/appearance"
	elif [[ -f "$prefs" ]]; then
		python3 - "$prefs" <<-'EOF'
			import json, sys
			p = sys.argv[1]
			d = json.load(open(p))
			d.setdefault("browser", {})["custom_chrome_frame"] = False
			json.dump(d, open(p, "w"), separators=(",", ":"))
		EOF
		info "Brave usará la barra del sistema"
	else
		info "Brave aún no tiene perfil: ábrelo una vez y repite este paso"
	fi
fi

# ---------------------------------------------------------------- 6. sistema

step "6. Sistema (sudo)"
S="$REPO/system"

if ask "¿Login con greetd + ReGreet (sustituye a SDDM/el login que haya)?"; then
	sudo install -Dm644 -t /etc/greetd "$S"/etc/greetd/{config.toml,regreet.toml,regreet.css,environments}
	sudo install -Dm644 "$S/usr/share/backgrounds/greeter.jpg" /usr/share/backgrounds/greeter.jpg
	sudo sed -i "s|^greeting_msg = .*|greeting_msg = \"$(cat /etc/hostname 2>/dev/null || echo cachyos)\"|" /etc/greetd/regreet.toml
	for dm in sddm gdm lightdm ly; do
		systemctl is-enabled "$dm" &>/dev/null && sudo systemctl disable "$dm"
	done
	sudo systemctl enable greetd
fi

if ask "¿Tema de arranque Plymouth \"canalla\"?"; then
	sudo rm -rf /usr/share/plymouth/themes/canalla
	sudo cp -r "$S/usr/share/plymouth/themes/canalla" /usr/share/plymouth/themes/
	sudo plymouth-set-default-theme canalla
	info "regenerando el initramfs..."
	if command -v limine-mkinitcpio >/dev/null; then
		sudo limine-mkinitcpio
	else
		sudo mkinitcpio -P
	fi
fi

if ask "¿Intercambiar Alt y Super en el teclado del portátil (keyd, ThinkPad)?"; then
	sudo install -Dm644 "$S/etc/keyd/thinkpad.conf" /etc/keyd/thinkpad.conf
	sudo systemctl enable --now keyd
fi

if ask "¿Activar servicios (NetworkManager, bluetooth, power-profiles-daemon)?"; then
	sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon
fi

# ---------------------------------------------------------------- fin

step "Listo"
info "Reinicia y entra en la sesión Hyprland (uwsm)."
info "Cosas que seguramente quieras cambiar:"
info "  ~/.config/hypr/config/monitors.lua y variables.lua   monitores y apps por defecto"
info "  ~/.config/hypr/config/inputs.lua                     distribución de teclado"
info "  Super+T                                              cambiar de tema"
