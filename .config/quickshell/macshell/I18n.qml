pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Translations. Texts are in English in the code and tr() looks them up in
// i18n/<language>.json (language from LC_ALL > LC_MESSAGES > LANG). With no file or
// no key the English text stays. Placeholders %1, %2…
Singleton {
    id: root
    readonly property string lang: (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").split(/[_.@]/)[0]
    // blockAllReads: text() reads the file right away, so the first binding pass comes out translated
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

    // Date format without year, taken from the long format of Qt.locale() (LC_TIME, the same
    // one that provides the names): "dddd, d 'de' MMMM" with es_ES, "dddd, MMMM d" with en_US.
    // weekday: with the day of the week; short: abbreviated and without commas ("ddd MMM d")
    function dateFormat(weekday, short) {
        let f = Qt.locale().dateFormat(Locale.LongFormat).replace(/[\s,.]*('[^']*'\s*)?y+[^\w']*/, "");
        if (!weekday)
            f = f.replace(/d{4}[^\w']*/, "");
        return short ? f.replace("dddd", "ddd").replace("MMMM", "MMM").replace(/,/g, "") : f;
    }
}
