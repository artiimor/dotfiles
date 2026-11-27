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
| `nvim` | Nombre del colorscheme: `catppuccin-mocha`, `catppuccin-macchiato`, `catppuccin-frappe`, `catppuccin-latte`, `tokyonight`, `rose-pine`, `rose-pine-dawn`, `gruvbox`, `kanagawa-dragon`, `everforest`, `dracula` | Neovim |
| `nvimColors.syn` | Colores de sintaxis (string, fun, keyword, comment...) del colorscheme "tema"; sin ellos mini.hues queda casi gris. Todos los temas los traen, sacados de su paleta original | Neovim |
| `nvimColors.ui` | Opcional: pisa colores de la interfaz de "tema" (ver abajo) | Neovim |
| `light` | `true` en los temas claros (sin él, oscuro): decide Mac claro u oscuro y GTK claro u oscuro (ver abajo) | config-set |

Cuándo se ve el cambio: Quickshell, Hyprland, kitty, Ghostty y los Neovim abiertos
(theme-set les manda `background` y el colorscheme por su socket) al momento; btop
y las apps GTK y Qt al volver a abrirlas; fzf y fastfetch (el Pepe, teñido con el
acento) en terminales nuevas; hyprlock en el próximo bloqueo.

Fuera de los temas: ReGreet (gris oscuro estilo macOS) y Plymouth ("sobrio"). La pantalla
de bloqueo sigue con el Pepe de noche.

## Fondos de pantalla

Como en Omarchy, cada tema puede traer sus fondos en `<tema>/backgrounds/`
(jpg, png, webp...). **Super+Ctrl+B** los muestra con miniaturas (más los Pepes
de siempre) y **Super+Ctrl+Shift+B** pasa al siguiente. «＋ Añadir fondos…» abre
esa carpeta en Dolphin para arrastrar imágenes. Se recuerda uno por tema;
sin elegir, el primero (los Pepes si el tema no trae). También desde la terminal
con `background-set` (ver el script).

## Fuente

La fuente monoespaciada va aparte del tema: no está en `theme.json` y no cambia al
cambiar de tema ni con `--reapply`. Se elige en la pestaña **Fuente** de Super+T
(cada fila escrita con su fuente) o con `font-set "<familia>"` (`font-set` sin nada
lista las Nerd Fonts monoespaciadas instaladas, una por familia). Se guarda en
`~/.local/state/font` y font-set escribe `kitty/font.conf`, `ghostty/font.ghostty` y
`hypr/font.conf` (hyprbars en Modo normal, con la variante "Propo" si existe). Sin
elegir ninguna, cada programa sigue con la suya: GeistMono en kitty, la de Ghostty
por defecto y JetBrains Mono en hyprbars. La interfaz de Quickshell, hyprlock y el
Modo Mac siguen con la suya.

## Temas claros

`catppuccin-latte`, `rose-pine-dawn` y `snow` son claros (`"light": true`), con los 16
colores ANSI de sus paletas originales (`snow`, todo en grises). En los temas claros theme-set no usa
`colors[0]`/`colors[15]` para la fila elegida de fzf y btop (usa
`term.selection_background` y `ui.fg`) ni para los relieves de Qt (los calcula
desde los botones); en los oscuros todo sigue igual. Los Neovim abiertos reciben
`background=light|dark` junto con el colorscheme, y la pantalla de bloqueo
(Quickshell y hyprlock) pone el texto casi blanco sobre el fondo de noche.

En el menú de temas (Super+T) cada fila lleva su paleta (fondo y texto del
terminal, acento y 6 colores) y un sol o una luna según sea claro u oscuro. Los
temas van en dos pestañas, **Oscuros** y **Claros** (la tercera, **Fuente**, es la de
font-set); se abre en la del tema activo,
con él elegido. Se cambia de pestaña con clic, Tab / Shift+Tab o ←/→. Cada pestaña tiene su buscador
(escribir filtra; al volver a una pestaña sigue lo que escribiste en ella), y en Fuente
se encuentran también por el nombre original (p. ej. "Cascadia" → CaskaydiaCove).

## Neovim

El colorscheme "tema" (`nvim/colors/tema.lua`, el mismo en LazyVim) saca toda la
interfaz de la paleta del tema, no solo la sintaxis: números de línea, línea del
cursor, selección (`term.selection_background`), menús y flotantes
(`ui.launcherBg`, fila elegida `ui.launcherSel`, borde `ui.border` al 25 %),
statusline, pestañas, separadores, búsqueda (`ui.accent`), diagnósticos
(`ui.red`, `ui.yellow`, `ui.cyan`, `ui.accent2`, `ui.ok`) y diff. El fondo sigue
transparente. Si un color de fondo coincide con el del terminal (`term.background`),
se usa el siguiente que se distinga.

`nvimColors.ui` (opcional) pisa cualquiera de estas claves: `panel` (menús,
flotantes, statusline), `sel`, `cursorline`, `visual`, `linenr` (por defecto =
`nontext`), `nontext` y `special` (por defecto `ui.muted`), `whitespace` (por defecto
`ui.accentDim`), `border`, `dim`, `accent`, `accent2`, `muted`, `red`, `yellow`, `ok`,
`info`, `hint`. Para probar un tema sin cambiar el activo:
`TEMA_THEME_JSON=~/.config/themes/snow/theme.json nvim`.

## Configs: Modo Mac / Modo normal

Además del tema de colores hay dos perfiles del escritorio. Se cambian con
**Super+Shift+T** (menú "Config": *Modo Mac* y *Modo normal*) o
`~/.config/themes/config-set mac|default` (`config-set` sin nada lista los
perfiles). Se aplica al momento, sin cerrar sesión.

| | Modo Mac | Modo normal (`default`) |
|---|---|---|
| Barra, notificaciones | macshell (`quickshell/macshell`) | la de Quickshell de aquí |
| Super+Espacio / Super+Esc / Super+A | Spotlight / PowerMenu / centro de macshell | lanzador / menú de energía / notificaciones de aquí |
| Ventanas | esquinas de 10 px y sombra | rectas, sombra por defecto |
| hyprbars | gris Sur-Gris, Noto Sans, 32 px | color del tema, fuente de font-set (JetBrains Mono), 28 px |
| Iconos (GTK, Qt, Dolphin) | Sur-Transparente (Sur con tema claro) | Papirus-Dark (Papirus-Light con tema claro) |
| Qt (qt6ct) | Breeze, colores `mac-dark.conf`, Noto Sans | Fusion, colores del tema (`current.conf`) |
| Workspaces | todos flotantes; Super+Alt+D pasa uno a tiling | tiling; Super+Alt+D pasa uno a flotante |

**Claro u oscuro lo decide el tema de colores.** En Modo Mac, con un tema claro
el perfil pasa a **Mac claro** (`mac-light`, interno): macshell y hyprbars claros,
iconos Sur, GTK `adw-gtk3` + `prefer-light` con un `gtk.css` claro fijo (theme-set
no lo pisa en este perfil) y Qt con `mac-light.conf`; con uno oscuro vuelve a `mac`.
Lo hace theme-set al cambiar de tema (llama a `sync_theme()` de config-set, que
reinicia Quickshell solo si cambia la claridad), y `config-set mac` con un tema
claro ya guarda `mac-light`. `config-set mac-light` sigue sirviendo para forzarlo a
mano (hasta el próximo cambio de tema o `--reapply`). Las terminales siguen con el tema de colores.

En Modo normal, un tema claro pone GTK `adw-gtk3` + `prefer-light` (con el `gtk.css`
del tema) e iconos Papirus-Light; Qt, Hyprland, hyprbars y la barra ya salen del tema.

En Modo Mac, las ventanas de la Quickshell de aquí que se siguen usando
(menús del lanzador: temas, configs, portapapeles, emojis, atajos...; OSD, polkit
y dock) copian el aspecto de macshell (`Theme.mac` en `quickshell/Theme.qml`).

Común a los dos: tema de colores (en Mac no recolorea las apps Qt ni hyprbars),
cursor macOS (negro), keyd (Alt/Super intercambiados, HHKB intacto), Super+Shift+Espacio
= lanzador de apps, `QT_QPA_PLATFORMTHEME=qt6ct`, reglas de ventanas, etc.

El perfil se guarda en `~/.local/state/desktop-profile` y lo leen
`hypr/config/profile.lua` y `quickshell/shell.qml`. Sin ese archivo se usa
"mac" si está macshell y "default" si no.

