// Servidor de notificaciones: sustituye a swaync. Guarda el historial,
// decide qué sale como popup y lleva el "no molestar" y el panel.
//
// Desde fuera (atajos de Hyprland):
//   qs ipc call notifs toggle   abrir/cerrar el panel
//   qs ipc call notifs dnd      no molestar
//   qs ipc call notifs clear    borrar todas
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Historial (las más nuevas al final)
    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length

    // Las que se están mostrando ahora como popup (las más nuevas primero)
    property var popups: []

    property bool dnd: false
    property bool centerOpen: false

    // Hora de llegada de cada notificación (por id), para "hace 5 min"
    property var times: ({})

    // Reloj que avanza cada minuto para refrescar los "hace X min"
    readonly property date now: clock.date
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Al hacer clic fuera del panel se cierra; si ese clic era en la campana,
    // el toggle lo volvería a abrir. Esto lo evita.
    property real _closedAt: 0
    function togglePanel() {
        if (!centerOpen && Date.now() - _closedAt < 300)
            return;
        centerOpen = !centerOpen;
    }
    function closePanel() {
        if (centerOpen) {
            centerOpen = false;
            _closedAt = Date.now();
        }
    }
    onCenterOpenChanged: if (centerOpen) popups = []

    // Historial agrupado por app, como en swaync: [{ app, notifs }]
    // Los grupos y las notificaciones de cada grupo van de más nueva a más vieja
    readonly property var groups: {
        const map = new Map();
        for (const n of list.slice().reverse()) {
            const app = n.appName || "Otras";
            if (!map.has(app))
                map.set(app, []);
            map.get(app).push(n);
        }
        return [...map].map(([app, notifs]) => ({ app, notifs }));
    }

    // Grupos desplegados en el panel (por nombre de app)
    property var expanded: ({})
    function toggleGroup(app) {
        const e = Object.assign({}, expanded);
        e[app] = !e[app];
        expanded = e;
    }
    function clearGroup(notifs) { for (const n of notifs.slice()) n.dismiss(); }

    function toggleDnd() { dnd = !dnd; }
    function clearAll() { for (const n of list.slice()) n.dismiss(); }
    function hidePopup(n) { popups = popups.filter(p => p !== n); }

    function timeAgo(n) {
        const t = times[n.id];
        if (!t)
            return "";
        const min = Math.floor((now - t) / 60000);
        if (min < 1)
            return "ahora";
        if (min < 60)
            return `hace ${min} min`;
        const h = Math.floor(min / 60);
        return h < 24 ? `hace ${h} h` : `hace ${Math.floor(h / 24)} d`;
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
            // Sin esto la notificación se descarta en cuanto se cierra el popup
            n.tracked = true;
            root.times[n.id] = new Date();
            n.closed.connect(() => root.hidePopup(n));

            // Con "no molestar" solo salen las críticas
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
