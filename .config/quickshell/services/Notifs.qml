// Notification server: replaces swaync. Keeps the history,
// decides what shows as a popup and handles "do not disturb" and the panel.
//
// From outside (Hyprland shortcuts):
//   qs ipc call notifs toggle   open/close the panel
//   qs ipc call notifs dnd      do not disturb
//   qs ipc call notifs clear    clear all
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs
import qs.components

Singleton {
    id: root

    // History (newest at the end)
    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length

    // The ones currently shown as popups (newest first)
    property var popups: []

    property bool dnd: false
    property bool centerOpen: false

    // Arrival time of each notification (by id), for "5 min ago". Changed
    // without notifying: recorded before the card reading it exists. On reloading
    // qs the notifications stay (keepOnReload) but this is lost, and the ones
    // already there don't show the time until new ones arrive
    property var times: ({})

    // Clock ticking every minute to refresh the "X min ago"
    readonly property date now: clock.date
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // So the click outside the panel that closes it doesn't reopen it if it was on the bell
    ReopenGuard { id: guard }
    function togglePanel() {
        if (centerOpen || guard.canOpen())
            centerOpen = !centerOpen;
    }
    function closePanel() {
        if (centerOpen) {
            centerOpen = false;
            guard.closed();
        }
    }
    onCenterOpenChanged: if (centerOpen) popups = []

    // History grouped by app, like in swaync: [{ app, notifs }]
    // Groups and the notifications in each group go from newest to oldest
    readonly property var groups: {
        const map = new Map();
        for (const n of list.slice().reverse()) {
            const app = n.appName || I18n.tr("Other");
            if (!map.has(app))
                map.set(app, []);
            map.get(app).push(n);
        }
        return [...map].map(([app, notifs]) => ({ app, notifs }));
    }

    // Groups expanded in the panel (by app name)
    property var expanded: ({})
    function toggleGroup(app) {
        const e = Object.assign({}, expanded);
        e[app] = !e[app];
        expanded = e;
    }
    function clearGroup(notifs) { for (const n of notifs.slice()) n.dismiss(); }

    function toggleDnd() { dnd = !dnd; }
    function clearAll() { clearGroup(list); }
    function hidePopup(n) { popups = popups.filter(p => p !== n); }

    function timeAgo(n) {
        const t = times[n.id];
        if (!t)
            return "";
        const min = Math.floor((now - t) / 60000);
        if (min < 1)
            return I18n.tr("now");
        if (min < 60)
            return I18n.tr("%1 min ago", min);
        const h = Math.floor(min / 60);
        return h < 24 ? I18n.tr("%1 h ago", h) : I18n.tr("%1 d ago", Math.floor(h / 24));
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            // Before tracked: entering the history already creates its card
            root.times[n.id] = new Date();
            // Without this the notification is discarded as soon as the popup closes
            n.tracked = true;
            n.closed.connect(() => {
                root.hidePopup(n);
                delete root.times[n.id];
            });

            // With "do not disturb" only critical ones show
            const show = !root.centerOpen && (!root.dnd || n.urgency === NotificationUrgency.Critical);
            if (show)
                root.popups = [n, ...root.popups.filter(p => p !== n)];
        }
    }

    IpcHandler {
        target: "notifs"
        function toggle(): void { root.togglePanel(); }
        function dnd(): void { root.toggleDnd(); }
        function clear(): void { root.clearAll(); }
    }
}
