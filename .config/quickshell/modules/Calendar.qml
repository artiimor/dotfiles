// Calendario del mes, para el tooltip del reloj. Lunes primero.
import QtQuick
import qs

Column {
    id: root
    spacing: 6

    // Mes mostrado, relativo al actual (la rueda sobre el reloj lo mueve)
    property int offset: 0
    function shift(n) { offset += n; }
    function reset() { offset = 0; }

    readonly property date today: new Date()
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)

    // 42 celdas (6 semanas); null = hueco
    readonly property var days: {
        const first = (month.getDay() + 6) % 7; // 0 = lunes
        const count = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = i - first + 1;
            out.push(d >= 1 && d <= count ? d : null);
        }
        return out;
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.month.toLocaleDateString(Qt.locale(), "MMMM yyyy")
        color: Theme.accent
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
    }

    Grid {
        columns: 7
        columnSpacing: 4
        rowSpacing: 2

        Repeater {
            model: ["L", "M", "X", "J", "V", "S", "D"]
            Text {
                required property string modelData
                width: 26
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.accent2
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }

        Repeater {
            model: root.days
            Rectangle {
                required property var modelData
                readonly property bool isToday: root.offset === 0 && modelData === root.today.getDate()
                width: 26
                height: 20
                radius: 5
                color: isToday ? Theme.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData ?? ""
                    color: parent.isToday ? Theme.bgSolid : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: parent.isToday
                }
            }
        }
    }
}
