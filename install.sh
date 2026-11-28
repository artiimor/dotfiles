#!/usr/bin/env bash
# Installs this desktop on a freshly installed CachyOS.
#
#   git clone https://github.com/artiimor/wasdjy.git ~/.local/share/wasdjy
#   ~/.local/share/wasdjy/install.sh            asks before each step
#   ~/.local/share/wasdjy/install.sh --yes      does everything without asking
#   ~/.local/share/wasdjy/install.sh --update   only steps 3 and 4, without asking (used by wasdjy-update)
#
# The repo lives in ~/.local/share/wasdjy and its bin/ (wasdjy-theme, wasdjy-config...) goes
# in the PATH (uwsm/env, .profile). Cloned somewhere else (e.g. ~/src/wasdjy), step 3 links
# ~/.local/share/wasdjy to it.
#
# Steps (each one can be skipped):
#   1. Desktop packages (pacman) and AUR ones (bzmenu, WhiteSur icons) with makepkg
#   1b. GPU: missing drivers and NVIDIA variables if it's the primary one (not on hybrids)
#   2. Extra apps (Firefox, Brave, Spotify, Discord, Proton...)
#   3. Files: ~/.local/share/wasdjy, pending migrations (bin/wasdjy-migrate), .config (with macshell), .bashrc, webapps, Sur icons -> ~ (whatever gets replaced goes to ~/.local/state/wasdjy/backup/<date>) and bash as shell
#   4. Color theme (wasdjy-theme) and Mac Mode / Normal Mode profile (wasdjy-config)
#   5. hyprbars plugin with the desktop-mode patches (and removes GTK/Brave's own buttons)
#   6. System (sudo): greetd + ReGreet, Plymouth "sobrio", keyd (ThinkPad), automatic
#      time zone, more password attempts before lockout (faillock), power profile
#      based on the power source (udev), services
#
# Run it as your user, not as root: it asks for sudo when needed.
# Safe to re-run: pacman uses --needed, whatever is overwritten goes to ~/.local/state/wasdjy/backup
# and monitors.lua, variables.lua, inputs.lua, the user.* files and the chosen theme are kept if they already exist.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WASDJY="$HOME/.local/share/wasdjy"
# Color theme: the one you already have (not lost when re-running the install), otherwise grafito
THEME="$(basename "$(readlink "$HOME/.config/themes/current" 2>/dev/null)" 2>/dev/null)"
[[ -f "$REPO/.config/themes/$THEME/theme.json" ]] || THEME="grafito"
YES=0 UPDATE=0
case "${1:-}" in
--yes | -y) YES=1 ;;
# --update: files, theme and migrations of an existing install, without asking
--update) YES=1 UPDATE=1 ;;
esac

# t (translated messages), step, info, warn and ask, from the repo itself
# (~/.local/share/wasdjy may not exist yet)
# shellcheck source=lib/wasdjy.sh
. "$REPO/lib/wasdjy.sh"

# ---------------------------------------------------------------- packages

# Desktop: Hyprland + Quickshell and what the binds and the bar use
# (fd, libqalculate and python-gobject: macshell's Spotlight and clipboard)
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
# Terminal, shell and Neovim
TERMINAL=(
	ghostty starship btop fastfetch bash-completion fzf eza bat
	neovim lazygit ripgrep tree-sitter-cli nodejs npm micro
	python python-defusedxml git base-devel rsync
)
FONTS=(
	ttf-jetbrains-mono-nerd otf-geist-mono-nerd inter-font cantarell-fonts
	# More monospace Nerd Fonts for wasdjy-font (Super+T, Font)
	ttf-firacode-nerd ttf-hack-nerd ttf-cascadia-code-nerd ttf-sourcecodepro-nerd
	ttf-ubuntu-mono-nerd otf-commit-mono-nerd ttf-mononoki-nerd ttf-ibmplex-mono-nerd
	ttf-0xproto-nerd ttf-martian-mono-nerd ttf-roboto-mono-nerd
	noto-fonts noto-fonts-emoji noto-fonts-cjk
)
# Login and boot
SYSTEM=(greetd greetd-regreet cage plymouth keyd)
# Not in the repos: built from AUR
# whitesur-icon-theme: base of the Mac Mode Sur icons
AUR=(bzmenu whitesur-icon-theme)
# Opcionales
APPS=(firefox brave-bin spotify-launcher discord proton-pass proton-vpn-gtk-app claude-code github-cli)

# ---------------------------------------------------------------- utilities

if [[ $EUID -eq 0 ]]; then
	echo "$(t "Run it as your user, not as root.")" >&2
	exit 1
fi
if ! command -v pacman >/dev/null; then
	echo "$(t "This is for CachyOS/Arch (pacman not found).")" >&2
	exit 1
fi

BACKUP="$HOME/.local/state/wasdjy/backup/$(date +%Y%m%d-%H%M%S)"
ME="$(id -un)"

# Asks for sudo once and keeps it alive (AUR builds can take a while).
# Not with --update: steps 3 and 4 hardly need it
if ((!UPDATE)); then
	sudo -v
	while sleep 60; do sudo -n true; done 2>/dev/null &
	SUDO_KEEPALIVE=$!
	trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT
fi

# Config files edited by hand: if they already exist they aren't overwritten on re-runs
KEEP=(hypr/config/monitors.lua hypr/config/variables.lua hypr/config/inputs.lua themes/current
	hypr/config/user.lua ghostty/user.ghostty nvim/lua/user.lua)

# Backup of a file from /etc (or similar) before overwriting it
backup_sys() {
	local f
	for f; do
		# sudo only for reading: the copy belongs to the user
		# shellcheck disable=SC2024
		[[ -e "$f" ]] && mkdir -p "$BACKUP/system${f%/*}" && sudo cat "$f" >"$BACKUP/system$f"
	done
	return 0
}

# install_sys SRC DST: installs a system file (644), first backing up whatever was there
install_sys() {
	backup_sys "$2"
	sudo install -Dm644 "$1" "$2"
}

regen_initramfs() {
	info "$(t "regenerating the initramfs...")"
	if command -v limine-mkinitcpio >/dev/null; then
		sudo limine-mkinitcpio
	else
		sudo mkinitcpio -P
	fi
}

# Installs with pacman whatever is in the repos; for the rest it warns (e.g. packages
# only in CachyOS on plain Arch) and tries an AUR helper if there is one
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

# ~/.local/share/wasdjy -> this repo, if it was cloned somewhere else. A symlink pointing
# elsewhere is replaced; a real folder (another clone) is left alone with a warning
link_repo() {
	[[ "$(realpath "$WASDJY" 2>/dev/null)" == "$(realpath "$REPO")" ]] && return 0
	if [[ -e "$WASDJY" && ! -L "$WASDJY" ]]; then
		warn "$(t "%1 already exists and is not this repo: the wasdjy-* commands will run from there" "$WASDJY")"
		return 0
	fi
	mkdir -p "${WASDJY%/*}"
	ln -sfn "$REPO" "$WASDJY"
	info "$(t "%1 -> %2" "~/.local/share/wasdjy" "$REPO")"
}

# Old names (~/.config/themes/theme-set...), still used by binds or scripts of your own:
# symlinks to bin/wasdjy-*. The old copies (and their themelib.py and i18n/) go to $BACKUP.
# Temporary, while migrating: they will be removed in a future version
OLD_SCRIPTS=(theme config background font contrast)
compat_links() {
	local d="$HOME/.config/themes" n f
	mkdir -p "$d"
	for f in "$d/themelib.py" "$d/i18n"; do
		[[ -e "$f" && ! -L "$f" ]] && mkdir -p "$BACKUP/.config/themes" && mv "$f" "$BACKUP/.config/themes/"
	done
	for n in "${OLD_SCRIPTS[@]}"; do
		f="$d/$n-set"
		[[ -e "$f" && ! -L "$f" ]] && mkdir -p "$BACKUP/.config/themes" && mv "$f" "$BACKUP/.config/themes/"
		ln -sfn "$WASDJY/bin/wasdjy-$n" "$f"
	done
	return 0
}

# Copies src -> dst; whatever is overwritten is saved in $BACKUP with the same path
copy_tree() {
	local src="$1" dst="$2" rel="${2#"$HOME"/}" k excl=()
	mkdir -p "$dst"
	for k in "${KEEP[@]}"; do
		[[ -e "$dst/$k" || -L "$dst/$k" ]] && excl+=(--exclude "/$k")
	done
	rsync -a --backup --backup-dir="$BACKUP/$rel" "${excl[@]}" "$src/" "$dst/"
}

# The few files that need an absolute path contain @HOME@: it is replaced with your $HOME.
# Only the ones shipped by the repo are touched, nothing else in ~/.config
fix_home() {
	local f home="${HOME//&/\\&}"
	while IFS= read -rd '' f; do
		[[ -f "$HOME/$f" ]] && sed -i "s|@HOME@|$home|g" "$HOME/$f"
	done < <(cd "$REPO" && grep -rlIZ '@HOME@' .config .local 2>/dev/null)
	return 0
}

# gen_monitors FILE: writes a monitors.lua with one rule per connected screen.
# Outputs come from hyprctl if Hyprland is running, otherwise from /sys/class/drm.
# Scale guessed by resolution (internal eDP/LVDS/DSI panel = laptop); if it doesn't divide
# the resolution exactly, "auto". If nothing is detected the file is left alone (the general rule stays)
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
		-- Created by install.sh with the screens present at the first install;
		-- from here on it's yours (names: hyprctl monitors all). Scale is a rough guess.

		-- General rule (output "" = any screen, e.g. one plugged in later)
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

# GPU: detects GPUs over PCI (class 0x03xx) and offers the missing drivers.
# NVIDIA only gets environment variables if it's the primary one (the only one, or the one the
# firmware used at boot: boot_vga). On a hybrid (iGPU + NVIDIA) forcing them breaks the session.
# The variables go to ~/.config/uwsm/env.d/gpu, regenerated on every run.
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
	((intel)) && pkgs+=(intel-media-driver) # Intel VA-API (mesa already ships AMD's)
	if ((nvidia)); then
		if pacman -Qq nvidia-utils &>/dev/null; then
			info "$(t "NVIDIA drivers already installed (%1)" "$(pacman -Q nvidia-utils)")"
		elif command -v chwd >/dev/null; then
			# CachyOS: chwd picks the right driver for the card
			ask "$(t "Install the NVIDIA drivers with chwd?")" && { sudo chwd -a || warn "$(t "%1 failed" chwd)"; }
		else
			# Arch: open module (Turing/RTX 20 or later; older ones need
			# the proprietary driver of their branch) with the headers of each installed kernel
			nv=(nvidia-open-dkms nvidia-utils egl-wayland libva-nvidia-driver)
			# only headers that are in the repos: nothing derived from the system goes to AUR
			for k in /usr/lib/modules/*/pkgbase; do
				[[ -r "$k" ]] && pacman -Si "$(<"$k")-headers" &>/dev/null && nv+=("$(<"$k")-headers")
			done
			# Asked even with --yes: on a pre-Turing card the open
			# module doesn't work and nvidia-utils blacklists nouveau (no graphics after reboot)
			read -rp "    $(t "Install %1? (RTX 20/GTX 16 or newer only) [y/N]" "${nv[*]}") " r || r=""
			[[ "$r" =~ ^[sSyY] ]] && { sudo pacman -S --needed --noconfirm "${nv[@]}" || warn "$(t "could not install the NVIDIA drivers")"; }
		fi
	fi
	((${#pkgs[@]})) && ask "$(t "Install %1?" "${pkgs[*]}")" && pacman_install "${pkgs[@]}"
	# Without the proprietary driver installed, the variables would break GLX and VA-API (nouveau)
	if ((primary)) && ! pacman -Qq nvidia-utils &>/dev/null; then
		warn "$(t "NVIDIA without the proprietary driver: its environment variables are not set")"
		primary=0
	fi

	if ((primary)); then
		mkdir -p "${env%/*}"
		[[ -L "$env" ]] && rm -f "$env" # don't write through a symlink (stow...)
		printf '%s\n' "$mark" "export LIBVA_DRIVER_NAME=nvidia" \
			"export __GLX_VENDOR_LIBRARY_NAME=nvidia" "export NVD_BACKEND=direct" >"$env"
		info "$(t "NVIDIA variables in %1" "~/.config/uwsm/env.d/gpu")"
	else
		((nvidia)) && info "$(t "NVIDIA in a hybrid: no global variables (the iGPU draws the desktop)")"
		# only deleted if this script generated it
		[[ -f "$env" ]] && head -1 "$env" | grep -qxF "$mark" && rm -f "$env"
	fi
	return 0
}

# Steps 1, 1b and 2 (packages): not with --update (wasdjy-update runs pacman -Syu itself)
if ((!UPDATE)); then

	# ---------------------------------------------------------------- 1. packages

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

fi

# ---------------------------------------------------------------- 3. files

step "$(t "3. Configuration files")"
info "$(t "%1 -> ~/.config, .bashrc, .bash_profile, .profile, webapps, Sur icons" "$REPO/.config")"
info "$(t "%1 -> %2 (wasdjy-* commands)" "$REPO" "~/.local/share/wasdjy")"
info "$(t "whatever gets overwritten is saved in %1" "$BACKUP")"
if ask "$(t "Copy them?")"; then
	command -v rsync >/dev/null || sudo pacman -S --needed --noconfirm rsync
	link_repo
	# monitors.lua: if it doesn't exist yet (first install) it is generated with the detected screens
	mon="$HOME/.config/hypr/config/monitors.lua"
	[[ -e "$mon" ]] && mon=""
	# Migrations (migrations/, see bin/wasdjy-migrate), before copying the new files: a fresh
	# install is already up to date (all marked as applied); an existing one runs the pending ones
	if [[ -n "$mon" ]]; then
		"$REPO/bin/wasdjy-migrate" --mark-all
	elif ! "$REPO/bin/wasdjy-migrate"; then
		again="$0"
		((UPDATE)) && again=wasdjy-update
		warn "$(t "stopping: fix the migration and run %1 again" "$again")"
		exit 1
	fi
	copy_tree "$REPO/.config" "$HOME/.config"
	[[ -z "$mon" ]] || gen_monitors "$mon"
	copy_tree "$REPO/.local/share/applications" "$HOME/.local/share/applications"
	copy_tree "$REPO/.local/share/icons" "$HOME/.local/share/icons"
	# Icon cache: without it, every GTK app walks all its directories at start-up
	if command -v gtk-update-icon-cache >/dev/null; then
		for d in "$REPO"/.local/share/icons/*/; do
			gtk-update-icon-cache -q -f -t "$HOME/.local/share/icons/$(basename "$d")" || true
		done
	fi
	# -c: like copy_tree, but a backup is only kept if the content changes (not the date)
	rsync -ac --backup --backup-dir="$BACKUP" "$REPO"/{.bashrc,.bash_profile,.profile} "$HOME/"
	fix_home
	compat_links
	chmod +x "$REPO/bin/"* "$HOME/.config/quickshell/scripts/"* 2>/dev/null || true
	# Cursor: the black macOS arrow (apple_cursor, not in the Arch repos).
	# If it can't be downloaded Adwaita stays. ~/.icons/default is for X11 apps
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
			# hypr/config/environment.lua reads uwsm/env: changing it here is enough
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

# CachyOS sets fish as the default shell; this repo's config is for bash (.bashrc)
if ((!UPDATE)) && [[ "$(getent passwd "$ME" | cut -d: -f7)" != */bash ]] && ask "$(t "Use bash as your shell (instead of fish)?")"; then
	sudo chsh -s /bin/bash "$ME"
	info "$(t "shell changed to bash: takes effect on your next login")"
fi

# ---------------------------------------------------------------- 4. theme

step "$(t "4. Color theme")"
# From the repo itself: the PATH doesn't have bin/ until the next login
if [[ -d "$HOME/.config/themes" ]] && ask "$(t "Apply the %1 theme?" "$THEME")"; then
	"$REPO/bin/wasdjy-theme" "$THEME" || warn "$(t "%1 failed; run it again inside Hyprland" wasdjy-theme)"
fi
# Desktop profile (Super+Shift+T): the one you already had; on a fresh install, "mac".
# Adjusts GTK/Qt icons and qt6ct to that profile (the repo ships them as in "mac")
if [[ -d "$HOME/.config/themes" ]]; then
	"$REPO/bin/wasdjy-config" --reapply || warn "$(t "%1 failed; run it again inside Hyprland" wasdjy-config)"
fi

# --update ends here: hyprbars and the system parts aren't touched
((UPDATE)) && exit 0

# ---------------------------------------------------------------- 5. hyprbars

step "$(t "5. Title bars (patched hyprbars)")"
info "$(t "built with the same version as the installed Hyprland")"
if command -v Hyprland >/dev/null && ask "$(t "Build hyprbars?")"; then
	ver="$(Hyprland --version 2>/dev/null | grep -oP 'Hyprland \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)" || true
	[[ -n "$ver" ]] || { warn "$(t "can't tell the Hyprland version; trying the one from pacman")"; ver="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}' | cut -d- -f1)" || true; }
	dir="$(mktemp -d)"
	# hyprland-plugins only tags some versions (v0.57.0 works for 0.57.1).
	# The patches are applied in alphabetical order (hover-icon, on-drag-end, resize-top-edge)
	if git clone https://github.com/hyprwm/hyprland-plugins "$dir/hp" &&
		{ git -C "$dir/hp" checkout -q "v$ver" 2>/dev/null ||
			git -C "$dir/hp" checkout -q "v${ver%.*}.0"; } &&
		git -C "$dir/hp" apply "$REPO"/.config/hypr/hyprbars-*.patch &&
		make -C "$dir/hp/hyprbars" all; then
		# to a temporary name and mv (new inode): Hyprland has the old .so mapped
		# with dlopen and overwriting it in place can crash it (SIGBUS)
		install -Dm755 "$dir/hp/hyprbars/hyprbars.so" "$HOME/.local/lib/hyprland/.hyprbars.so.new"
		mv -f "$HOME/.local/lib/hyprland/.hyprbars.so.new" "$HOME/.local/lib/hyprland/hyprbars.so"
		info "$(t "hyprbars v%1 installed in %2" "$ver" "~/.local/lib/hyprland")"
		info "$(t "if an update bumps the Hyprland version, repeat this step")"
	else
		warn "$(t "could not build it (no v%1 tag in hyprland-plugins?). Everything works without it, just without title bars." "$ver")"
	fi
	rm -rf "$dir"
fi

# The close/minimize/maximize buttons come from hyprbars (macOS style):
# the ones drawn by the apps themselves are removed so they don't show twice
if ask "$(t "Remove the window buttons drawn by GTK and Brave (keeping only the hyprbars ones)?")"; then
	# GTK 4 / libadwaita reads it from here; GTK 3 from gtk-3.0/settings.ini (step 3)
	gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:' 2>/dev/null || true
	# Brave: "Use system title bar and borders" (brave://settings/appearance).
	# With Brave open the change is lost when it closes, so it's only touched when closed
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

# ---------------------------------------------------------------- 6. system

step "$(t "6. System (sudo)")"
S="$REPO/system"

if ask "$(t "Log in with greetd + ReGreet (replaces SDDM or whatever login manager you have)?")"; then
	for f in config.toml regreet.toml regreet.css environments; do
		install_sys "$S/etc/greetd/$f" "/etc/greetd/$f"
	done
	sudo install -Dm644 "$S/usr/share/backgrounds/greeter.jpg" /usr/share/backgrounds/greeter.jpg
	# Greeting: the hostname. Clock language: the system date locale (localectl: LC_TIME
	# or, if not set, LANG) without ".UTF-8", e.g. "es_ES", and its format translated to that language
	loc="$(localectl status 2>/dev/null | grep -oP '\b(LC_TIME|LANG)=\S+' | sort -r | head -1)" || true
	loc="${loc#*=}"
	loc="${loc:-${LC_TIME:-${LANG:-}}}"
	loc="${loc%%[.@]*}"
	[[ "$loc" =~ ^[a-z]{2,3}_[A-Z]{2}$ ]] || loc=en_US
	clock="$(LC_ALL="" LC_MESSAGES="" LANG="$loc" t "%A, %B %d  ·  %H:%M" 2>/dev/null)"
	sudo sed -i -e "s|^greeting_msg = .*|greeting_msg = \"$(cat /etc/hostname 2>/dev/null || echo cachyos)\"|" \
		-e "s|^format = .*|format = \"$clock\"|" -e "s|^locale = .*|locale = \"$loc\"|" /etc/greetd/regreet.toml
	# Whatever login manager is active is disabled so greetd takes display-manager.service
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
	regen_initramfs
fi

# keyd: thinkpad.conf is for the ThinkPad internal keyboard. Detected via DMI: on a
# ThinkPad the default answer is yes; on other machines it's no (also with --yes).
# hypr/config/keyd.lua only changes keyd if /etc/keyd/thinkpad.conf exists.
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
	# hypr/config/keyd.lua changes the map with "keyd bind": the keyd group is required
	if getent group keyd >/dev/null && ! id -nG "$ME" | grep -qw keyd; then
		sudo usermod -aG keyd "$ME"
		info "$(t "added to the keyd group: takes effect on your next login")"
	fi
fi

# When connecting to a network, NetworkManager sets the location's time zone (see the script header)
info "$(t "automatic time zone: sends your public IP to ipinfo.io when you connect (not over VPN)")"
if ask "$(t "Automatic time zone based on the network?")"; then
	backup_sys /etc/NetworkManager/dispatcher.d/90-timezone
	# NetworkManager only runs root scripts nobody else can write
	sudo install -Dm755 "$S/etc/NetworkManager/dispatcher.d/90-timezone" /etc/NetworkManager/dispatcher.d/90-timezone
	# On Arch the service that runs those scripts isn't enabled by default
	sudo systemctl enable NetworkManager-dispatcher.service
fi

# faillock: 10 failures in a row lock the account for 10 min (default 3); affects sudo and the lock screen
if ask "$(t "Allow 10 password attempts before locking the account (instead of 3)?")"; then
	install_sys "$S/etc/security/faillock.conf" /etc/security/faillock.conf
fi

# Automatic power profile: power-saver on battery, balanced when plugged in (laptops only)
if grep -qsx Battery /sys/class/power_supply/*/type &&
	ask "$(t "Power saver profile on battery and balanced when plugged in?")"; then
	install_sys "$S/etc/udev/rules.d/90-power-profile.rules" /etc/udev/rules.d/90-power-profile.rules
	sudo udevadm control --reload
fi

# Less RAM: huge pages only on request and a smaller GPU page pool (see the file headers).
# The ttm module loads from the initramfs, so its option needs a new one (applies on reboot)
if ask "$(t "Reduce RAM use (huge pages on request, smaller GPU page pool)?")"; then
	install_sys "$S/etc/tmpfiles.d/wasdjy-memory.conf" /etc/tmpfiles.d/wasdjy-memory.conf
	sudo systemd-tmpfiles --create /etc/tmpfiles.d/wasdjy-memory.conf
	install_sys "$S/etc/modprobe.d/wasdjy-ttm.conf" /etc/modprobe.d/wasdjy-ttm.conf
	regen_initramfs
fi

if ask "$(t "Enable services (NetworkManager, bluetooth, power-profiles-daemon)?")"; then
	sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon
fi

# ---------------------------------------------------------------- end

step "$(t "Done")"
[[ -d "$BACKUP" ]] && info "$(t "backups of what was overwritten (including /etc) in %1" "$BACKUP")"
info "$(t "Reboot and log into the Hyprland (uwsm) session.")"
info "$(t "Things you will probably want to change:")"
info "$(t "  ~/.config/hypr/config/monitors.lua and variables.lua  monitors and default apps")"
info "$(t "  ~/.config/hypr/config/inputs.lua                      keyboard layout")"
info "$(t "  Super+T                                               change theme")"
