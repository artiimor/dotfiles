pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    // Aspecto claro para el perfil de escritorio "mac-light" (~/.config/themes/config-set
    // mac-light en los dotfiles), solo en Hyprland. theme-set pasa de mac a mac-light y al
    // revés sin reiniciar macshell (con renombrado atómico): se vigila el archivo.
    property FileView _profile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/desktop-profile"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property bool light: _profile.loaded && _profile.text().trim() === "mac-light"

    // "Aumentar contraste" (como la accesibilidad de macOS): ~/.config/themes/contrast-set
    // escribe "1" o "0" en el archivo de estado (con renombrado atómico; si no existe, apagado).
    // Con él, los fondos translúcidos se vuelven opacos y bordes, texto tenue y capas se marcan más.
    property FileView _contrast: FileView {
        path: Quickshell.env("HOME") + "/.local/state/increased-contrast"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property bool contrast: _contrast.loaded && _contrast.text().trim() === "1"
    // quita la transparencia con contraste alto
    function solid(c) { return contrast ? Qt.rgba(c.r, c.g, c.b, 1) : c; }

    readonly property color card: solid(light ? Qt.rgba(0.96, 0.96, 0.97, 0.86) : Qt.rgba(0.16, 0.16, 0.17, 0.80))
    readonly property color cardHover: solid(light ? Qt.rgba(0.91, 0.91, 0.92, 0.90) : Qt.rgba(0.20, 0.20, 0.21, 0.86))
    readonly property color border: light ? Qt.rgba(0, 0, 0, contrast ? 0.5 : 0.10) : Qt.rgba(1, 1, 1, contrast ? 0.5 : 0.10)
    // líneas divisorias y contorno de módulos y controles: casi invisibles normalmente,
    // bien marcados con contraste (outlineWidth pone borde a lo que normalmente no lo tiene)
    readonly property color separator: contrast ? (light ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.45)) : tint(0.1)
    readonly property color outline: contrast ? separator : tint(0.06)
    readonly property int outlineWidth: contrast ? 1 : 0
    readonly property color text: light ? "#1d1d1f" : "#f5f5f7"
    readonly property color dim: light ? Qt.rgba(0.11, 0.11, 0.12, contrast ? 0.85 : 0.55) : Qt.rgba(0.92, 0.92, 0.96, contrast ? 0.85 : 0.55)
    readonly property color button: tint(0.10)
    readonly property color buttonHover: tint(0.18)
    readonly property color accent: light ? "#007aff" : "#0a84ff"
    readonly property color red: light ? "#ff3b30" : "#ff453a"   // aviso (temperatura crítica)
    // capas: blanco en el aspecto oscuro, negro en el claro. No es tint(): la píldora de
    // BarButton anima la opacidad y en claro quiere la misma que en oscuro, sin el × 0.6
    readonly property color ink: light ? "black" : "white"
    function tint(a) {
        const k = contrast ? 1.6 : 1;
        return light ? Qt.rgba(0, 0, 0, a * 0.6 * k) : Qt.rgba(1, 1, 1, a * k);
    }
    // barra superior (Hyprland), Spotlight, ventana de Red
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

    // regiones de blur de las tarjetas (Card) de un ListView
    function cardBlurs(view) { return view.contentItem.children.filter(c => c.blur).map(c => c.blur); }

    // Reloj compartido por la barra, el calendario y el "X min ago". Solo cambia
    // una vez por minuto, así que los bindings que lo usan se reevalúan una vez por minuto.
    property date now: new Date()
    // hora de llegada de cada notificación, por id
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

    // Despierta al cambiar de minuto, pero como mucho cada 5 s: los timers no avanzan
    // durante la suspensión, así el reloj no se queda atrasado al reanudar.
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
