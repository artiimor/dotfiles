# Temas de color

Cada carpeta con un `theme.json` es un tema. `current` es un enlace al tema activo.

- Cambiar de tema: **Super+Ctrl+T**, o `~/.config/themes/theme-set <carpeta>`
- Ver los temas: `~/.config/themes/theme-set`
- Tras editar el `theme.json` del tema activo: `~/.config/themes/theme-set --reapply`

## Crear uno nuevo

1. Copia una carpeta: `cp -r miami mi-tema`
2. Cambia `name` (lo que sale en el menú) y los colores de `theme.json`
3. Elígelo en Super+Ctrl+T

## Qué es cada parte de theme.json

| Sección | Para qué | Programas |
|---|---|---|
| `ui` | Barra, launcher, notificaciones, OSD, bloqueo | Quickshell, hyprlock |
| `ui.launcherBg` / `ui.launcherSel` | Fondo del launcher y de su fila elegida | Quickshell |
| `ui.border` | Borde fino de las islas (se usa al 25 %) | Quickshell |
| `hypr.border` | Degradado del borde de la ventana activa (2 o más colores) | Hyprland |
| `hypr.inactive` | Borde de ventanas inactivas, admite transparencia `#rrggbbaa` | Hyprland |
| `hypr.group` | Borde de grupos de ventanas | Hyprland |
| `term` | Fondo, texto, cursor, selección y los 16 colores ANSI (`colors[0..15]`) | kitty, btop, fzf, starship |
| `gtk` | Ventanas, cabeceras, tarjetas y acento | apps GTK3/GTK4 |
| `nvim` | Nombre del colorscheme: `catppuccin`, `tokyonight`, `rose-pine`, `gruvbox` | Neovim |

Cuándo se ve el cambio: Quickshell, Hyprland y kitty al momento; btop, Neovim
y las apps GTK al volver a abrirlas; fzf en terminales nuevas; hyprlock en el
próximo bloqueo.

Fuera de los temas (se quedan con Miami night): ReGreet, Plymouth, Dolphin/Qt,
fastfetch (el Pepe) y el fondo de pantalla.
