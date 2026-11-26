// Batería del portátil (UPower). En un sobremesa no hay: `present` queda en
// false y la barra y la pantalla de bloqueo no la enseñan.
// También avisa de batería baja (notify-send: la pinta el servidor de notificaciones
// activo, el de aquí o el de macshell). shell.qml lo crea siempre, en los dos perfiles.
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

    // Aviso de batería baja: una notificación al bajar de 15 % y otra al bajar de 5 %,
    // solo descargando. Al enchufar o subir de umbral el nivel vuelve a 100 y se rearma
    readonly property int lowLevel: !present || !device.ready || !UPower.onBattery || percent <= 0 ? 100
        : percent <= 5 ? 5 : percent <= 15 ? 15 : 100
    property int lastLevel: 100
    onLowLevelChanged: {
        if (lowLevel < lastLevel)
            Quickshell.execDetached(lowLevel === 5
                ? ["notify-send", "-a", "Batería", "-u", "critical", "-i", "battery-caution", "Batería crítica", percent + " %: enchufa el portátil"]
                : ["notify-send", "-a", "Batería", "-i", "battery-low", "Batería baja", percent + " % restante"]);
        lastLevel = lowLevel;
    }
}
