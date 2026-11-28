// Wayland session lock: covers every screen with LockSurface
// until Lock.locked goes back to false (correct password).
import QtQuick
import Quickshell.Wayland
import qs.services

WlSessionLock {
    locked: Lock.locked

    WlSessionLockSurface {
        color: "black"

        LockSurface {}
    }
}
