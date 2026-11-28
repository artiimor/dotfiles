# Migraciones

Scripts que se ejecutan **una sola vez por máquina** para llevar una instalación existente al
estado actual. Los ejecuta `bin/wasdjy-migrate`, desde `install.sh` (paso 3, antes de copiar los
archivos) y por tanto desde `wasdjy-update`.

- **Cuándo**: todo cambio que afecte a instalaciones existentes y que copiar los archivos no
  arregla: renombrar o mover un archivo (el viejo se queda en `~`), un paquete nuevo, un setting
  fuera de `~/.config` (gsettings, `/etc`, un servicio)…
- **Nombre**: `AAAAMMDD-descripcion.sh` (p. ej. `20261124-cursor-macos.sh`). El orden alfabético
  es el de ejecución.
- **Idempotente** si se puede: que repetirla no rompa nada (comprobar antes de mover o instalar).
- Se ejecuta con `bash -euo pipefail` (no hace falta shebang ni permiso de ejecución), desde
  cualquier directorio. Variables: `REPO` (el repo, `~/.local/share/wasdjy`) y `HOME`.
  Para `sudo pacman -S --needed …`, pedirá la contraseña.
- **Falla con exit ≠ 0**: `wasdjy-migrate` avisa, no la marca y se para (las siguientes no se
  ejecutan); se reintenta en la próxima actualización.
- Las aplicadas se guardan en `~/.local/state/wasdjy/migrations`. En una instalación nueva se
  marcan todas sin ejecutarlas (`wasdjy-migrate --mark-all`).
