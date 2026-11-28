pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    // Light look for the "mac-light" desktop profile (wasdjy-config
    // mac-light in the dotfiles), only in Hyprland. wasdjy-theme switches from mac to mac-light and
    // back without restarting macshell (with an atomic rename): the file is watched.
    property FileView _profile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/desktop-profile"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property bool light: _profile.loaded && _profile.text().trim() === "mac-light"

    // "Increase contrast" (like macOS accessibility): wasdjy-contrast
    // writes "1" or "0" to the state file (with an atomic rename; if missing, off).
    // With it, translucent backgrounds become opaque and borders, dim text and layers are more marked.
    property FileView _contrast: FileView {
        path: Quickshell.env("HOME") + "/.local/state/increased-contrast"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property bool contrast: _contrast.loaded && _contrast.text().trim() === "1"
    // removes transparency with high contrast
    function solid(c) { return contrast ? Qt.rgba(c.r, c.g, c.b, 1) : c; }

    readonly property color card: solid(light ? Qt.rgba(0.96, 0.96, 0.97, 0.86) : Qt.rgba(0.16, 0.16, 0.17, 0.80))
    readonly property color cardHover: solid(light ? Qt.rgba(0.91, 0.91, 0.92, 0.90) : Qt.rgba(0.20, 0.20, 0.21, 0.86))
    readonly property color border: light ? Qt.rgba(0, 0, 0, contrast ? 0.5 : 0.10) : Qt.rgba(1, 1, 1, contrast ? 0.5 : 0.10)
    // divider lines and outline of modules and controls: almost invisible normally,
    // clearly marked with contrast (outlineWidth adds a border to what normally has none)
    readonly property color separator: contrast ? (light ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.45)) : tint(0.1)
    readonly property color outline: contrast ? separator : tint(0.06)
    readonly property int outlineWidth: contrast ? 1 : 0
    readonly property color text: light ? "#1d1d1f" : "#f5f5f7"
    readonly property color dim: light ? Qt.rgba(0.11, 0.11, 0.12, contrast ? 0.85 : 0.55) : Qt.rgba(0.92, 0.92, 0.96, contrast ? 0.85 : 0.55)
    readonly property color button: tint(0.10)
    readonly property color buttonHover: tint(0.18)
    readonly property color accent: light ? "#007aff" : "#0a84ff"
    readonly property color red: light ? "#ff3b30" : "#ff453a"   // warning (critical temperature)
    // layers: white in the dark look, black in the light one. It isn't tint(): the
    // BarButton pill animates the opacity and in light it wants the same as in dark, without the × 0.6
    readonly property color ink: light ? "black" : "white"
    function tint(a) {
        const k = contrast ? 1.6 : 1;
        return light ? Qt.rgba(0, 0, 0, a * 0.6 * k) : Qt.rgba(1, 1, 1, a * k);
    }
    // top bar (Hyprland), Spotlight, Network window
    readonly property color panel: solid(light ? Qt.rgba(0.96, 0.96, 0.97, 0.78) : Qt.rgba(0x20 / 255, 0x23 / 255, 0x26 / 255, 0.8))
    readonly property color overlay: solid(light ? Qt.rgba(0.97, 0.97, 0.98, 0.86) : Qt.rgba(0.13, 0.13, 0.14, 0.82))
    readonly property color window: light ? "#ececec" : "#1e1e1e"
    readonly property color wsActive: light ? "#007aff" : "#3080aa"
    readonly property color sliderFill: light ? "white" : "#f5f5f7"
    readonly property color closeButton: solid(light ? Qt.rgba(0.88, 0.88, 0.90, 0.96) : Qt.rgba(0.28, 0.28, 0.30, 0.96))
    readonly property color closeButtonHover: light ? Qt.rgba(0.80, 0.80, 0.82, 1) : Qt.rgba(0.40, 0.40, 0.42, 1)
    readonly property int radius: 16
    readonly property int width: 360
    readonly property int popupTimeout: 5000
    readonly property var locale: Qt.locale()

    // blur regions of the cards (Card) in a ListView
    function cardBlurs(view) { return view.contentItem.children.filter(c => c.blur).map(c => c.blur); }

    // Clock shared by the bar, the calendar and "X min ago". It only changes
    // once a minute, so the bindings using it are re-evaluated once a minute.
    property date now: new Date()
    // arrival time of each notification, by id
    property var times: ({})

    function stamp(id) { times[id] = new Date(); }
    function forget(id) { delete times[id]; }

    function ago(id) {
        const t = times[id];
        if (!t) return I18n.tr("now");
        const m = Math.floor((now - t) / 60000);
        if (m < 1) return I18n.tr("now");
        if (m < 60) return I18n.tr("%1 min ago", m);
        const h = Math.floor(m / 60);
        if (h < 24) return I18n.tr("%1 h ago", h);
        return locale.toString(t, I18n.dateFormat(false, true) + " HH:mm");
    }

    // Wakes up when the minute changes, but at most every 5 s: timers don't advance
    // during suspend, so the clock doesn't lag behind after resuming.
    property Timer _tick: Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            const d = new Date();
            if (d.getMinutes() !== theme.now.getMinutes() || Math.abs(d - theme.now) >= 60000)
                theme.now = d;
            interval = Math.min(5000, 60000 - d.getSeconds() * 1000 - d.getMilliseconds() + 20);
        }
    }
}
