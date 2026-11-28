// Laptop battery (UPower). On a desktop there is none: `present` stays
// false and the bar and the lock screen don't show it.
// Also warns about low battery (notify-send: drawn by the active notification
// server, this one or macshell's). shell.qml always creates it, in both profiles.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool present: device?.isLaptopBattery ?? false
    // Depending on the backend it comes as 0–1 or 0–100
    readonly property int percent: {
        const p = device?.percentage ?? 0;
        return Math.round(p > 1 ? p : p * 100);
    }
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    // Plugged in but not charging (full or with a charge threshold)
    readonly property bool plugged: !UPower.onBattery && !charging

    // Low battery warning: one notification when dropping below 15 % and another below 5 %,
    // only while discharging. When plugging in or rising above the threshold the level goes back to 100 and it re-arms
    readonly property int lowLevel: !present || !device.ready || !UPower.onBattery || percent <= 0 ? 100
        : percent <= 5 ? 5 : percent <= 15 ? 15 : 100
    property int lastLevel: 100
    onLowLevelChanged: {
        if (lowLevel < lastLevel)
            Quickshell.execDetached(lowLevel === 5
                ? ["notify-send", "-a", I18n.tr("Battery"), "-u", "critical", "-i", "battery-caution", I18n.tr("Battery critical"), I18n.tr("%1%: plug in the laptop", percent)]
                : ["notify-send", "-a", I18n.tr("Battery"), "-i", "battery-low", I18n.tr("Battery low"), I18n.tr("%1% left", percent)]);
        lastLevel = lowLevel;
    }
}
