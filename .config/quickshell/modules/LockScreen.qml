// Bloqueo de sesión de Wayland: cubre todas las pantallas con LockSurface
// hasta que Lock.locked vuelve a false (contraseña correcta).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

WlSessionLock {
    locked: Lock.locked

    WlSessionLockSurface {
        color: "black"

        LockSurface {}
    }
}
