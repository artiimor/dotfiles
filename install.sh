#!/usr/bin/env bash
# Instala este escritorio sobre un CachyOS recién instalado.
#
#   git clone https://github.com/artiimor/dotfiles.git ~/dotfiles
#   ~/dotfiles/install.sh            pregunta antes de cada paso
#   ~/dotfiles/install.sh --yes      lo hace todo sin preguntar
#
# Pasos (cada uno se puede saltar):
#   1. Paquetes del escritorio (pacman) y los de AUR (bzmenu, iconos WhiteSur) con makepkg
#   1b. Gráfica: drivers que falten y variables de NVIDIA si es la principal (no en híbridos)
#   2. Apps extra (Firefox, Brave, Spotify, Discord, Proton...)
#   3. Dotfiles: .config (con macshell), .bashrc, webapps, iconos Sur -> ~ (lo que pisa va a ~/.dotfiles-old/<fecha>) y bash como shell
#   4. Tema de colores (theme-set) y perfil Modo Mac / Modo normal (config-set)
#   5. Plugin hyprbars con los parches del modo escritorio (y quita los botones propios de GTK/Brave)
#   6. Sistema (sudo): greetd + ReGreet, Plymouth "sobrio", keyd (ThinkPad), zona horaria
#      automática, más intentos de contraseña antes del bloqueo (faillock), perfil de
#      energía según la corriente (udev), servicios
#
# Ejecútalo como tu usuario, no como root: pide sudo cuando lo necesita.
# Se puede repetir sin miedo: pacman usa --needed, lo que se sobrescribe va a ~/.dotfiles-old
# y monitors.lua, variables.lua, inputs.lua, los archivos user.* y el tema elegido se respetan si ya existen.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Tema de colores: el que ya tengas (al repetir la instalación no se pierde), si no grafito
THEME="$(basename "$(readlink "$HOME/.config/themes/current" 2>/dev/null)" 2>/dev/null)"
[[ -f "$REPO/.config/themes/$THEME/theme.json" ]] || THEME="grafito"
YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && YES=1

# Traducción de los mensajes con el themelib.py del repo (puede que ~/.config/themes
# aún no exista): t "Text %1" arg. Sin python3, en inglés con los %N cambiados aquí
t() {
	python3 "$REPO/.config/themes/themelib.py" tr "$@" 2>/dev/null && return
	local s="$1" i=1 a
	shift
	for a; do s="${s//"%$i"/"$a"}" i=$((i + 1)); done
	printf '%s' "$s"
}

# ---------------------------------------------------------------- paquetes

# Escritorio: Hyprland + Quickshell y lo que usan los binds y la barra
# (fd, libqalculate y python-gobject: Spotlight y portapapeles de macshell)
DESKTOP=(
	hyprland quickshell uwsm xdg-desktop-portal-hyprland
	hypridle hyprlock hyprsunset hyprshot hyprpicker grim slurp
	cliphist wl-clipboard brightnessctl playerctl ddcutil
	pipewire-pulse wireplumber pavucontrol power-profiles-daemon upower
	networkmanager networkmanager-dmenu bluez bluez-utils
	gnome-keyring seahorse libnotify xdg-user-dirs unicode-emoji
	dolphin kde-cli-tools ffmpegthumbs ffmpegthumbnailer qview gnome-calculator gnome-text-editor swash
	qt6ct breeze nwg-look adw-gtk-theme papirus-icon-theme
	fd libqalculate python-gobject
)
# Terminal, shell y Neovim
TERMINAL=(
	ghostty starship btop fastfetch bash-completion fzf eza bat
	neovim lazygit ripgrep tree-sitter-cli nodejs npm micro
	python python-defusedxml git base-devel rsync
)
FONTS=(
	ttf-jetbrains-mono-nerd otf-geist-mono-nerd inter-font cantarell-fonts
	# Más Nerd Fonts monoespaciadas para font-set (Super+T, Fuente)
	ttf-firacode-nerd ttf-hack-nerd ttf-cascadia-code-nerd ttf-sourcecodepro-nerd
	ttf-ubuntu-mono-nerd otf-commit-mono-nerd ttf-mononoki-nerd ttf-ibmplex-mono-nerd
	ttf-0xproto-nerd ttf-martian-mono-nerd ttf-roboto-mono-nerd
	noto-fonts noto-fonts-emoji noto-fonts-cjk
)
# Login y arranque
SYSTEM=(greetd greetd-regreet cage plymouth keyd)
# No están en los repos: se compilan desde AUR
# whitesur-icon-theme: base de los iconos Sur del Modo Mac
AUR=(bzmenu whitesur-icon-theme)
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
	read -rp "    $1 $(t "[Y/n]") " r
	[[ -z "$r" || "$r" =~ ^[sSyY] ]]
}

if [[ $EUID -eq 0 ]]; then
	echo "$(t "Run it as your user, not as root.")" >&2
	exit 1
fi
if ! command -v pacman >/dev/null; then
	echo "$(t "This is for CachyOS/Arch (pacman not found).")" >&2
	exit 1
fi

BACKUP="$HOME/.dotfiles-old/$(date +%Y%m%d-%H%M%S)"
ME="$(id -un)"

# Pide sudo una vez y lo mantiene vivo (las compilaciones de AUR pueden tardar)
sudo -v
while sleep 60; do sudo -n true; done 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

# Archivos de config que se editan a mano: si ya existen no se pisan al repetir
KEEP=(hypr/config/monitors.lua hypr/config/variables.lua hypr/config/inputs.lua themes/current
	hypr/config/user.lua ghostty/user.ghostty nvim/lua/user.lua)

# Copia de un archivo de /etc (o similar) antes de sobrescribirlo
backup_sys() {
	local f
	for f; do
		# sudo solo para leer: la copia es del usuario
		# shellcheck disable=SC2024
		[[ -e "$f" ]] && mkdir -p "$BACKUP/system${f%/*}" && sudo cat "$f" >"$BACKUP/system$f"
	done
	return 0
}

# install_sys SRC DST: instala un archivo del sistema (644) guardando antes el que hubiera
install_sys() {
	backup_sys "$2"
	sudo install -Dm644 "$1" "$2"
}

# Instala con pacman lo que esté en los repos; lo que no, avisa (p. ej. paquetes
# solo de CachyOS en un Arch puro) y si hay un helper de AUR lo intenta por ahí
pacman_install() {
	local p ok=() missing=()
	for p; do
		if pacman -Si "$p" &>/dev/null || pacman -Qq "$p" &>/dev/null; then ok+=("$p"); else missing+=("$p"); fi
	done
	if ((${#ok[@]})) && ! sudo pacman -S --needed --noconfirm "${ok[@]}"; then
		warn "$(t "pacman failed (a conflict, e.g. pulseaudio or tuned-ppd?). Trying one by one")"
		for p in "${ok[@]}"; do
			sudo pacman -S --needed --noconfirm "$p" &>/dev/null || warn "$(t "could not install %1" "$p")"
		done
	fi
	((${#missing[@]})) && { warn "$(t "not in your repos: %1" "${missing[*]}")"; aur_install "${missing[@]}"; }
	return 0
}

# Copia src -> dst; lo que se sobrescriba se guarda en $BACKUP con la misma ruta
copy_tree() {
	local src="$1" dst="$2" rel="${2#"$HOME"/}" k excl=()
	mkdir -p "$dst"
	for k in "${KEEP[@]}"; do
		[[ -e "$dst/$k" || -L "$dst/$k" ]] && excl+=(--exclude "/$k")
	done
	rsync -a --backup --backup-dir="$BACKUP/$rel" "${excl[@]}" "$src/" "$dst/"
}

# Los pocos archivos que necesitan una ruta absoluta llevan @HOME@: se cambia por tu $HOME.
# Solo se tocan los que trae el repo, nada más de ~/.config
fix_home() {
	local f home="${HOME//&/\\&}"
	while IFS= read -rd '' f; do
		[[ -f "$HOME/$f" ]] && sed -i "s|@HOME@|$home|g" "$HOME/$f"
	done < <(cd "$REPO" && grep -rlIZ '@HOME@' .config .local 2>/dev/null)
	return 0
}

# gen_monitors ARCHIVO: escribe un monitors.lua con una regla por pantalla conectada.
# Las salidas salen de hyprctl si Hyprland está en marcha y si no de /sys/class/drm.
# Escala a ojo por resolución (panel interno eDP/LVDS/DSI = portátil); si no divide
# exacto la resolución, "auto". Si no detecta nada no toca el archivo (queda la regla general)
gen_monitors() {
	local out="$1" f name mode w h s rules=""
	local -A seen=()
	while read -r name mode; do
		[[ -n "$name" && -z "${seen[$name]:-}" && "$mode" =~ ^([0-9]+)x([0-9]+) ]] || continue
		seen[$name]=1 w=${BASH_REMATCH[1]} h=${BASH_REMATCH[2]} s=1
		if [[ "$name" =~ ^(eDP|LVDS|DSI) ]]; then
			if ((w >= 3200)); then s=2; elif ((w >= 2560)); then s=1.6; fi
		elif ((w >= 3840)); then
			s=1.5
		fi
		awk -v w="$w" -v h="$h" -v s="$s" 'BEGIN { x = w / s; y = h / s; exit !(x == int(x) && y == int(y)) }' || s=auto
		rules+=$'\n'"hl.monitor({ output = \"$name\", mode = \"preferred\", position = \"auto\", scale = \"$s\" })"
	done < <(
		if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v jq >/dev/null; then
			hyprctl monitors all -j 2>/dev/null | jq -r '.[] | "\(.name) \(.width)x\(.height)"'
		else
			for f in /sys/class/drm/card*-*/status; do
				[[ "$(cat "$f" 2>/dev/null)" == connected ]] || continue
				f="${f%/status}" name="${f##*/card}"
				echo "${name#*-} $(head -1 "$f/modes" 2>/dev/null)"
			done
		fi
	)
	[[ -n "$rules" ]] || return 0
	cat >"$out" <<-EOF
		-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/
		-- Creado por install.sh con las pantallas que había en la primera instalación;
		-- a partir de aquí es tuyo (nombres: hyprctl monitors all). Escala calculada a ojo.

		-- Regla general (output "" = cualquier pantalla, p. ej. una que se enchufe luego)
		hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
		$rules
	EOF
	info "$(t "monitors.lua generated with: %1" "${!seen[*]}")"
}

aur_install() {
	local pkg dir
	for pkg in "$@"; do
		if pacman -Qq "$pkg" &>/dev/null; then
			info "$(t "%1 is already installed" "$pkg")"
			continue
		fi
		if command -v paru >/dev/null; then
			paru -S --needed --noconfirm "$pkg" || warn "$(t "AUR: %1 failed, continuing" "$pkg")"
		elif command -v yay >/dev/null; then
			yay -S --needed --noconfirm "$pkg" || warn "$(t "AUR: %1 failed, continuing" "$pkg")"
		else
			dir="$(mktemp -d)"
			{ git clone --depth 1 "https://aur.archlinux.org/$pkg.git" "$dir/$pkg" &&
				(cd "$dir/$pkg" && makepkg -si --needed --noconfirm); } || warn "$(t "AUR: %1 failed, continuing" "$pkg")"
			rm -rf "$dir"
		fi
	done
	return 0
}

# Gráfica: detecta las GPU por PCI (clase 0x03xx) y ofrece los drivers que faltan.
# NVIDIA solo recibe variables de entorno si es la principal (única, o la que usó el
# firmware al arrancar: boot_vga). En un híbrido (iGPU + NVIDIA) forzarlas rompe la sesión.
# Las variables van a ~/.config/uwsm/env.d/gpu, que se regenera en cada ejecución.
gpu_setup() {
	local d nvidia=0 intel=0 amd=0 primary=0 pkgs=() nv=() k r=""
	local env="$HOME/.config/uwsm/env.d/gpu" mark="# Generado por install.sh: NVIDIA es la gráfica principal"
	for d in /sys/bus/pci/devices/*; do
		[[ -r "$d/class" && "$(<"$d/class")" == 0x03* ]] || continue
		case "$(<"$d/vendor")" in
		0x10de) nvidia=1; [[ "$(cat "$d/boot_vga" 2>/dev/null)" == 1 ]] && primary=1 ;;
		0x8086) intel=1 ;;
		0x1002) amd=1 ;;
		esac
	done
	((nvidia && !intel && !amd)) && primary=1
	info "$(t "detected:%1" "$( ((nvidia)) && printf ' NVIDIA')$( ((intel)) && printf ' Intel')$( ((amd)) && printf ' AMD')")"
	((intel)) && pkgs+=(intel-media-driver) # VA-API de Intel (AMD ya lo trae mesa)
	if ((nvidia)); then
		if pacman -Qq nvidia-utils &>/dev/null; then
			info "$(t "NVIDIA drivers already installed (%1)" "$(pacman -Q nvidia-utils)")"
		elif command -v chwd >/dev/null; then
			# CachyOS: chwd elige el driver adecuado para la tarjeta
			ask "$(t "Install the NVIDIA drivers with chwd?")" && { sudo chwd -a || warn "$(t "%1 failed" chwd)"; }
		else
			# Arch: módulo abierto (Turing/RTX 20 o posterior; las anteriores necesitan
			# el driver propietario de su rama) con las cabeceras de cada kernel instalado
			nv=(nvidia-open-dkms nvidia-utils egl-wayland libva-nvidia-driver)
			# solo cabeceras que estén en los repos: nada derivado del sistema va a AUR
			for k in /usr/lib/modules/*/pkgbase; do
				[[ -r "$k" ]] && pacman -Si "$(<"$k")-headers" &>/dev/null && nv+=("$(<"$k")-headers")
			done
			# Se pregunta aunque haya --yes: en una tarjeta anterior a Turing el módulo
			# abierto no funciona y nvidia-utils bloquea nouveau (sin gráficos al reiniciar)
			read -rp "    $(t "Install %1? (RTX 20/GTX 16 or newer only) [y/N]" "${nv[*]}") " r || r=""
			[[ "$r" =~ ^[sSyY] ]] && { sudo pacman -S --needed --noconfirm "${nv[@]}" || warn "$(t "could not install the NVIDIA drivers")"; }
		fi
	fi
	((${#pkgs[@]})) && ask "$(t "Install %1?" "${pkgs[*]}")" && pacman_install "${pkgs[@]}"
	# Sin el driver propietario instalado, las variables romperían GLX y VA-API (nouveau)
	if ((primary)) && ! pacman -Qq nvidia-utils &>/dev/null; then
		warn "$(t "NVIDIA without the proprietary driver: its environment variables are not set")"
		primary=0
	fi

	if ((primary)); then
		mkdir -p "${env%/*}"
		[[ -L "$env" ]] && rm -f "$env" # no escribir a través de un enlace (stow...)
		printf '%s\n' "$mark" "export LIBVA_DRIVER_NAME=nvidia" \
			"export __GLX_VENDOR_LIBRARY_NAME=nvidia" "export NVD_BACKEND=direct" >"$env"
		info "$(t "NVIDIA variables in %1" "~/.config/uwsm/env.d/gpu")"
	else
		((nvidia)) && info "$(t "NVIDIA in a hybrid: no global variables (the iGPU draws the desktop)")"
		# solo se borra si lo generó este script
		[[ -f "$env" ]] && head -1 "$env" | grep -qxF "$mark" && rm -f "$env"
	fi
	return 0
}

# ---------------------------------------------------------------- 1. paquetes

step "$(t "1. Desktop packages")"
info "$(t "%1 desktop, %2 terminal, %3 fonts, %4 login/boot, AUR: %5" "${#DESKTOP[@]}" "${#TERMINAL[@]}" "${#FONTS[@]}" "${#SYSTEM[@]}" "${AUR[*]}")"
if ask "$(t "Install the packages?")"; then
	sudo pacman -Syu --noconfirm || warn "$(t "could not update the system, continuing")"
	pacman_install "${DESKTOP[@]}" "${TERMINAL[@]}" "${FONTS[@]}" "${SYSTEM[@]}"
	aur_install "${AUR[@]}"
fi

step "$(t "1b. Graphics (GPU)")"
gpu_setup

# ---------------------------------------------------------------- 2. apps

step "$(t "2. Extra apps")"
info "${APPS[*]}"
if ask "$(t "Install the apps?")"; then
	pacman_install "${APPS[@]}"
fi

# ---------------------------------------------------------------- 3. dotfiles

step "3. Dotfiles"
info "$(t "%1 -> ~/.config, .bashrc, .bash_profile, .profile, webapps, Sur icons" "$REPO/.config")"
info "$(t "whatever gets overwritten is saved in %1" "$BACKUP")"
if ask "$(t "Copy them?")"; then
	command -v rsync >/dev/null || sudo pacman -S --needed --noconfirm rsync
	# monitors.lua: si aún no existe (primera instalación) se genera con las pantallas detectadas
	mon="$HOME/.config/hypr/config/monitors.lua"
	[[ -e "$mon" ]] && mon=""
	copy_tree "$REPO/.config" "$HOME/.config"
	[[ -z "$mon" ]] || gen_monitors "$mon"
	copy_tree "$REPO/.local/share/applications" "$HOME/.local/share/applications"
	copy_tree "$REPO/.local/share/icons" "$HOME/.local/share/icons"
	# -c: como copy_tree, pero solo se guarda copia si el contenido cambia (no por la fecha)
	rsync -ac --backup --backup-dir="$BACKUP" "$REPO"/{.bashrc,.bash_profile,.profile} "$HOME/"
	fix_home
	chmod +x "$HOME/.config/themes/theme-set" "$HOME/.config/themes/config-set" "$HOME/.config/themes/background-set" "$HOME/.config/themes/font-set" "$HOME/.config/themes/contrast-set" "$HOME/.config/quickshell/scripts/"* 2>/dev/null || true
	# Cursor: la flecha negra de macOS (apple_cursor, no está en los repos de Arch).
	# Si no se puede descargar se queda Adwaita. ~/.icons/default es para apps X11
	cursor=Adwaita
	cursor_dir="$HOME/.local/share/icons/macOS"
	cursor_sha=9c6e5e13b068ce51a9e90a9abd6ce232ec7d25d4ceb05aa8ac76efbb99c76762
	if [[ -f "$cursor_dir/index.theme" && -e "$cursor_dir/cursors/left_ptr" ]]; then
		cursor=macOS
	else
		mkdir -p "$HOME/.local/share/icons"
		tmp="$(mktemp)"
		if curl -fsSL --connect-timeout 10 --retry 2 -o "$tmp" \
			https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS.tar.xz &&
			echo "$cursor_sha  $tmp" | sha256sum -c --quiet - &&
			rm -rf "$cursor_dir" &&
			tar -xJf "$tmp" -C "$HOME/.local/share/icons" ./macOS; then
			cursor=macOS
		else
			rm -rf "$cursor_dir"
			warn "$(t "could not download the macOS cursor; using Adwaita")"
			sed -i 's/^gtk-cursor-theme-name=macOS/gtk-cursor-theme-name=Adwaita/' \
				"$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
			# hypr/config/environment.lua lee uwsm/env: basta con cambiarlo aquí
			sed -i 's/^export XCURSOR_THEME="macOS".*/export XCURSOR_THEME="Adwaita"/' "$HOME/.config/uwsm/env"
		fi
		rm -f "$tmp"
	fi
	mkdir -p "$HOME/.icons/default"
	printf '[Icon Theme]\nName=Default\nInherits=%s\n' "$cursor" >"$HOME/.icons/default/index.theme"
	gsettings set org.gnome.desktop.interface cursor-theme "$cursor" 2>/dev/null || true
	xdg-user-dirs-update 2>/dev/null || true
	[[ -d "$BACKUP" ]] && info "$(t "backups of the previous files in %1" "$BACKUP")"
fi

# CachyOS pone fish de shell por defecto; la config de este repo es la de bash (.bashrc)
if [[ "$(getent passwd "$ME" | cut -d: -f7)" != */bash ]] && ask "$(t "Use bash as your shell (instead of fish)?")"; then
	sudo chsh -s /bin/bash "$ME"
	info "$(t "shell changed to bash: takes effect on your next login")"
fi

# ---------------------------------------------------------------- 4. tema

step "$(t "4. Color theme")"
if [[ -x "$HOME/.config/themes/theme-set" ]] && ask "$(t "Apply the %1 theme?" "$THEME")"; then
	"$HOME/.config/themes/theme-set" "$THEME" || warn "$(t "%1 failed; run it again inside Hyprland" theme-set)"
fi
# Perfil del escritorio (Super+Shift+T): el que ya tuvieras; en una instalación nueva, "mac".
# Ajusta iconos GTK/Qt y qt6ct a ese perfil (el repo los trae como en "mac")
if [[ -x "$HOME/.config/themes/config-set" ]]; then
	"$HOME/.config/themes/config-set" --reapply || warn "$(t "%1 failed; run it again inside Hyprland" config-set)"
fi

# ---------------------------------------------------------------- 5. hyprbars

step "$(t "5. Title bars (patched hyprbars)")"
info "$(t "built with the same version as the installed Hyprland")"
if command -v Hyprland >/dev/null && ask "$(t "Build hyprbars?")"; then
	ver="$(Hyprland --version 2>/dev/null | grep -oP 'Hyprland \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)" || true
	[[ -n "$ver" ]] || { warn "$(t "can't tell the Hyprland version; trying the one from pacman")"; ver="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}' | cut -d- -f1)" || true; }
	dir="$(mktemp -d)"
	# hyprland-plugins solo etiqueta algunas versiones (v0.57.0 vale para 0.57.1).
	# Los parches se aplican en orden alfabético (hover-icon, on-drag-end, resize-top-edge)
	if git clone https://github.com/hyprwm/hyprland-plugins "$dir/hp" &&
		{ git -C "$dir/hp" checkout -q "v$ver" 2>/dev/null ||
			git -C "$dir/hp" checkout -q "v${ver%.*}.0"; } &&
		git -C "$dir/hp" apply "$REPO"/.config/hypr/hyprbars-*.patch &&
		make -C "$dir/hp/hyprbars" all; then
		# a un nombre temporal y mv (inodo nuevo): Hyprland tiene el .so viejo mapeado
		# con dlopen y sobrescribirlo en su sitio lo puede tumbar (SIGBUS)
		install -Dm755 "$dir/hp/hyprbars/hyprbars.so" "$HOME/.local/lib/hyprland/.hyprbars.so.new"
		mv -f "$HOME/.local/lib/hyprland/.hyprbars.so.new" "$HOME/.local/lib/hyprland/hyprbars.so"
		info "$(t "hyprbars v%1 installed in %2" "$ver" "~/.local/lib/hyprland")"
		info "$(t "if an update bumps the Hyprland version, repeat this step")"
	else
		warn "$(t "could not build it (no v%1 tag in hyprland-plugins?). Everything works without it, just without title bars." "$ver")"
	fi
	rm -rf "$dir"
fi

# Los botones de cerrar/minimizar/maximizar los pone hyprbars (estilo macOS):
# se quitan los que dibujan las propias apps para que no salgan dos veces
if ask "$(t "Remove the window buttons drawn by GTK and Brave (keeping only the hyprbars ones)?")"; then
	# GTK 4 / libadwaita lo lee de aquí; GTK 3 de gtk-3.0/settings.ini (paso 3)
	gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:' 2>/dev/null || true
	# Brave: "Usar la barra de título y los bordes del sistema" (brave://settings/appearance).
	# Con Brave abierto el cambio se pierde al cerrarlo, así que solo se toca si está cerrado
	prefs="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"
	if pgrep -x brave >/dev/null; then
		warn "$(t "Brave is open: close it and repeat this step, or enable it in brave://settings/appearance")"
	elif [[ -f "$prefs" ]]; then
		python3 - "$prefs" <<-'EOF'
			import json, sys
			p = sys.argv[1]
			import os
			with open(p) as f:
				d = json.load(f)
			d.setdefault("browser", {})["custom_chrome_frame"] = False
			with open(p + ".tmp", "w") as f:
				json.dump(d, f, separators=(",", ":"))
			os.replace(p + ".tmp", p)
		EOF
		info "$(t "Brave will use the system title bar")"
	else
		info "$(t "Brave has no profile yet: open it once and repeat this step")"
	fi
fi

# ---------------------------------------------------------------- 6. sistema

step "$(t "6. System (sudo)")"
S="$REPO/system"

if ask "$(t "Log in with greetd + ReGreet (replaces SDDM or whatever login manager you have)?")"; then
	for f in config.toml regreet.toml regreet.css environments; do
		install_sys "$S/etc/greetd/$f" "/etc/greetd/$f"
	done
	sudo install -Dm644 "$S/usr/share/backgrounds/greeter.jpg" /usr/share/backgrounds/greeter.jpg
	# Saludo: el hostname. Idioma del reloj: el de las fechas del sistema (localectl: LC_TIME
	# o, si no, LANG) sin ".UTF-8", p. ej. "es_ES", y su formato traducido a ese idioma
	loc="$(localectl status 2>/dev/null | grep -oP '\b(LC_TIME|LANG)=\S+' | sort -r | head -1)" || true
	loc="${loc#*=}"
	loc="${loc:-${LC_TIME:-${LANG:-}}}"
	loc="${loc%%[.@]*}"
	[[ "$loc" =~ ^[a-z]{2,3}_[A-Z]{2}$ ]] || loc=en_US
	clock="$(LC_ALL="" LC_MESSAGES="" LANG="$loc" t "%A, %B %d  ·  %H:%M" 2>/dev/null)"
	sudo sed -i -e "s|^greeting_msg = .*|greeting_msg = \"$(cat /etc/hostname 2>/dev/null || echo cachyos)\"|" \
		-e "s|^format = .*|format = \"$clock\"|" -e "s|^locale = .*|locale = \"$loc\"|" /etc/greetd/regreet.toml
	# El login que esté activo (sea cual sea) se desactiva para que greetd ocupe display-manager.service
	cur="$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" .service)"
	if [[ -n "$cur" && "$cur" != greetd ]]; then
		sudo systemctl disable "$cur" || warn "$(t "could not disable %1" "$cur")"
	fi
	sudo systemctl enable greetd || warn "$(t "could not enable greetd: check display-manager.service")"
fi

if ask "$(t "Plymouth boot theme \"sobrio\" (neutral grey)?")"; then
	sudo rm -rf /usr/share/plymouth/themes/sobrio /usr/share/plymouth/themes/canalla
	sudo cp -r "$S/usr/share/plymouth/themes/sobrio" /usr/share/plymouth/themes/
	sudo plymouth-set-default-theme sobrio
	grep -qw plymouth /etc/mkinitcpio.conf 2>/dev/null ||
		warn "$(t "the plymouth hook is missing from /etc/mkinitcpio.conf (and 'splash' from the kernel command line): without them it won't show")"
	info "$(t "regenerating the initramfs...")"
	if command -v limine-mkinitcpio >/dev/null; then
		sudo limine-mkinitcpio
	else
		sudo mkinitcpio -P
	fi
fi

# keyd: thinkpad.conf es para el teclado interno del ThinkPad. Se detecta por DMI: en un
# ThinkPad la respuesta por defecto es sí; en otro equipo es no (también con --yes).
# hypr/config/keyd.lua solo cambia keyd si existe /etc/keyd/thinkpad.conf.
KEYD_Q="$(t "Laptop keyboard with keyd: swap Alt and Super, and CapsLock as Control (made for ThinkPad)?")"
KEYD=0
if grep -qsi thinkpad /sys/class/dmi/id/product_version /sys/class/dmi/id/product_family; then
	info "$(t "ThinkPad detected")"
	ask "$KEYD_Q" && KEYD=1
elif ((!YES)); then
	read -rp "    $(t "%1 (this doesn't look like a ThinkPad) [y/N]" "$KEYD_Q") " r || r=""
	[[ "$r" =~ ^[sSyY] ]] && KEYD=1
else
	info "$(t "this doesn't look like a ThinkPad: skipping keyd")"
fi
if ((KEYD)); then
	install_sys "$S/etc/keyd/thinkpad.conf" /etc/keyd/thinkpad.conf
	sudo systemctl enable --now keyd
	# hypr/config/keyd.lua cambia el mapa con "keyd bind": hace falta el grupo keyd
	if getent group keyd >/dev/null && ! id -nG "$ME" | grep -qw keyd; then
		sudo usermod -aG keyd "$ME"
		info "$(t "added to the keyd group: takes effect on your next login")"
	fi
fi

# Al conectarse a una red, NetworkManager pone la zona horaria de la ubicación (ver la cabecera del script)
info "$(t "automatic time zone: sends your public IP to ipinfo.io when you connect (not over VPN)")"
if ask "$(t "Automatic time zone based on the network?")"; then
	backup_sys /etc/NetworkManager/dispatcher.d/90-timezone
	# NetworkManager solo ejecuta scripts de root que nadie más pueda escribir
	sudo install -Dm755 "$S/etc/NetworkManager/dispatcher.d/90-timezone" /etc/NetworkManager/dispatcher.d/90-timezone
	# En Arch el servicio que ejecuta esos scripts no viene activado
	sudo systemctl enable NetworkManager-dispatcher.service
fi

# faillock: 10 fallos seguidos bloquean la cuenta 10 min (por defecto 3); afecta a sudo y al bloqueo
if ask "$(t "Allow 10 password attempts before locking the account (instead of 3)?")"; then
	install_sys "$S/etc/security/faillock.conf" /etc/security/faillock.conf
fi

# Perfil de energía automático: ahorro con batería, equilibrado enchufado (solo en portátiles)
if grep -qsx Battery /sys/class/power_supply/*/type &&
	ask "$(t "Power saver profile on battery and balanced when plugged in?")"; then
	install_sys "$S/etc/udev/rules.d/90-power-profile.rules" /etc/udev/rules.d/90-power-profile.rules
	sudo udevadm control --reload
fi

if ask "$(t "Enable services (NetworkManager, bluetooth, power-profiles-daemon)?")"; then
	sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon
fi

# ---------------------------------------------------------------- fin

step "$(t "Done")"
[[ -d "$BACKUP" ]] && info "$(t "backups of what was overwritten (including /etc) in %1" "$BACKUP")"
info "$(t "Reboot and log into the Hyprland (uwsm) session.")"
info "$(t "Things you will probably want to change:")"
info "$(t "  ~/.config/hypr/config/monitors.lua and variables.lua  monitors and default apps")"
info "$(t "  ~/.config/hypr/config/inputs.lua                      keyboard layout")"
info "$(t "  Super+T                                               change theme")"
