pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Traducciones. Los textos van en inglés en el código y tr() los busca en
// i18n/<idioma>.json (idioma de LC_ALL > LC_MESSAGES > LANG). Sin archivo o
// sin la clave se queda el inglés. Marcadores %1, %2…
Singleton {
    id: root
    readonly property string lang: (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").split(/[_.@]/)[0]
    // blockAllReads: text() lee el archivo ya, así el primer pase de bindings sale traducido
    readonly property var dict: JSON.parse(file.text() || "{}")

    FileView {
        id: file
        path: ["", "en", "C", "POSIX"].includes(root.lang) ? "" : Quickshell.shellDir + "/i18n/" + root.lang + ".json"
        blockAllReads: true
        printErrors: false
    }

    function tr(s, ...args) {
        let r = root.dict[s] ?? s;
        args.forEach((a, i) => r = r.split("%" + (i + 1)).join(a));
        return r;
    }

    // Formato de fecha sin año, sacado del formato largo de Qt.locale() (LC_TIME, el mismo
    // que pone los nombres): "dddd, d 'de' MMMM" con es_ES, "dddd, MMMM d" con en_US.
    // weekday: con el día de la semana; short: abreviado y sin comas ("ddd MMM d")
    function dateFormat(weekday, short) {
        let f = Qt.locale().dateFormat(Locale.LongFormat).replace(/[\s,.]*('[^']*'\s*)?y+[^\w']*/, "");
        if (!weekday)
            f = f.replace(/d{4}[^\w']*/, "");
        return short ? f.replace("dddd", "ddd").replace("MMMM", "MMM").replace(/,/g, "") : f;
    }
}
