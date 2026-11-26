// Batería del portátil (UPower). En un sobremesa no hay: `present` queda en
// false y la barra y la pantalla de bloqueo no la enseñan.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool present: device?.isLaptopBattery ?? false
    // Según el backend viene como 0–1 o 0–100
    readonly property int percent: {
        const p = device?.percentage ?? 0;
        return Math.round(p > 1 ? p : p * 100);
    }
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    // Enchufado pero sin cargar (llena o con umbral de carga)
    readonly property bool plugged: !UPower.onBattery && !charging
}
