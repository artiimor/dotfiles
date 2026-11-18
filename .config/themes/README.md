# Temas de color

Cada carpeta con un `theme.json` es un tema. `current` es un enlace al tema activo.

- Cambiar de tema: **Super+T**, o `~/.config/themes/theme-set <carpeta>`
- Ver los temas: `~/.config/themes/theme-set`
- Tras editar el `theme.json` del tema activo: `~/.config/themes/theme-set --reapply`

## Crear uno nuevo

1. Copia una carpeta: `cp -r miami mi-tema`
2. Cambia `name` (lo que sale en el menú) y los colores de `theme.json`
3. Elígelo en Super+T

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
| `nvim` | Nombre del colorscheme: `catppuccin`, `tokyonight`, `rose-pine`, `gruvbox`, `kanagawa-dragon`, `everforest`, `dracula` | Neovim |

Cuándo se ve el cambio: Quickshell, Hyprland y kitty al momento; btop, Neovim
y las apps GTK al volver a abrirlas; fzf en terminales nuevas; hyprlock en el
próximo bloqueo.

Fuera de los temas (se quedan con Miami night): ReGreet, Plymouth, Dolphin/Qt,
fastfetch (el Pepe) y el fondo de pantalla.

## Configs: Mac / Default

Además del tema de colores hay dos perfiles del escritorio. Se cambian con
**Super+Shift+T** (menú "Config") o `~/.config/themes/config-set mac|default`
(`config-set` sin nada lista los perfiles). Se aplica al momento, sin cerrar sesión.

| | Config Mac | Config Default |
|---|---|---|
| Barra, notificaciones | macshell (repo plasma-mac) | la de Quickshell de aquí |
| Super+Espacio / Super+Esc / Super+A | Spotlight / PowerMenu / centro de macshell | lanzador / menú de energía / notificaciones de aquí |
| Ventanas | esquinas de 10 px y sombra | rectas, sombra por defecto |
| hyprbars | gris Sur-Gris, Noto Sans, 32 px | color del tema, JetBrains Mono, 28 px |
| Iconos (GTK, Qt, Dolphin) | Sur-Transparente | Papirus-Dark |
| Qt (qt6ct) | Breeze, colores `mac-dark.conf`, Noto Sans | Fusion, colores del tema (`current.conf`) |

Común a los dos: tema de colores (en Mac no recolorea las apps Qt ni hyprbars),
cursor Adwaita, keyd (Alt/Super intercambiados, HHKB intacto), Super+Shift+Espacio
= lanzador de apps, `QT_QPA_PLATFORMTHEME=qt6ct`, reglas de ventanas, etc.

El perfil se guarda en `~/.local/state/desktop-profile` y lo leen
`hypr/config/profile.lua` y `quickshell/shell.qml`. Sin ese archivo se usa
"mac" si está macshell y "default" si no.

