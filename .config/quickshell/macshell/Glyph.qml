import QtQuick

// Small hand-drawn vector icons so they always match the bar (monochrome, macOS style).
Canvas {
    id: g
    property string name: ""
    property color color: Theme.text
    property real level: 1          // wifi 0..3, altavoz 0..1
    property bool off: false        // silenciado / desactivado
    implicitWidth: 16
    implicitHeight: 16

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onLevelChanged: requestPaint()
    onOffChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const c = getContext("2d");
        c.reset();
        const s = width / 16;
        c.scale(s, s);
        c.strokeStyle = g.color;
        c.fillStyle = g.color;
        c.lineWidth = 1.6;
        c.lineCap = "round";
        c.lineJoin = "round";
        const dim = (on) => { c.globalAlpha = on ? 1 : 0.3; };

        switch (g.name) {
        case "wifi": {
            const cx = 8, cy = 13.2;
            for (let i = 1; i <= 3; i++) {
                dim(!g.off && g.level >= i);
                c.beginPath();
                c.arc(cx, cy, 3.6 * i, -Math.PI * 0.75, -Math.PI * 0.25);
                c.stroke();
            }
            dim(!g.off);
            c.beginPath(); c.arc(cx, cy, 1.3, 0, Math.PI * 2); c.fill();
            break;
        }
        case "search":
            c.lineWidth = 1.7;
            c.beginPath(); c.arc(6.6, 6.6, 4.6, 0, Math.PI * 2); c.stroke();
            c.lineWidth = 2;
            c.beginPath(); c.moveTo(10.2, 10.2); c.lineTo(14, 14); c.stroke();
            break;
        case "bluetooth":
        case "bluetooth-connected":   // with a dot on each side (device connected)
            dim(!g.off);
            c.lineWidth = 1.5;
            c.beginPath();
            c.moveTo(4.5, 5); c.lineTo(11.5, 11); c.lineTo(8, 14.2);
            c.lineTo(8, 1.8); c.lineTo(11.5, 5); c.lineTo(4.5, 11);
            c.stroke();
            if (g.name === "bluetooth-connected") {
                c.beginPath(); c.arc(2.2, 8, 1.1, 0, Math.PI * 2); c.fill();
                c.beginPath(); c.arc(13.8, 8, 1.1, 0, Math.PI * 2); c.fill();
            }
            break;
        case "speaker": {
            c.beginPath();
            c.moveTo(1.5, 6); c.lineTo(4.5, 6); c.lineTo(8.5, 2.5);
            c.lineTo(8.5, 13.5); c.lineTo(4.5, 10); c.lineTo(1.5, 10); c.closePath();
            c.fill();
            if (g.off) {
                c.lineWidth = 1.5;
                c.beginPath(); c.moveTo(10.5, 5.5); c.lineTo(15, 10.5);
                c.moveTo(15, 5.5); c.lineTo(10.5, 10.5); c.stroke();
            } else {
                c.lineWidth = 1.4;
                for (let i = 1; i <= 2; i++) {
                    dim(g.level > (i - 1) * 0.5);
                    c.beginPath(); c.arc(8.5, 8, 2.8 * i, -Math.PI / 4, Math.PI / 4); c.stroke();
                }
            }
            break;
        }
        case "sun":
            c.beginPath(); c.arc(8, 8, 3, 0, Math.PI * 2); c.fill();
            c.lineWidth = 1.4;
            for (let i = 0; i < 8; i++) {
                const a = i * Math.PI / 4;
                c.beginPath();
                c.moveTo(8 + Math.cos(a) * 5, 8 + Math.sin(a) * 5);
                c.lineTo(8 + Math.cos(a) * 6.8, 8 + Math.sin(a) * 6.8);
                c.stroke();
            }
            break;
        case "moon":
            c.beginPath(); c.arc(8, 8, 6, 0, Math.PI * 2); c.fill();
            c.globalCompositeOperation = "destination-out";
            c.beginPath(); c.arc(11.5, 5, 5.2, 0, Math.PI * 2); c.fill();
            c.globalCompositeOperation = "source-over";
            break;
        case "play":
            c.beginPath(); c.moveTo(4, 2.5); c.lineTo(13.5, 8); c.lineTo(4, 13.5); c.closePath(); c.fill();
            break;
        case "pause":
            roundRect(c, 3.5, 2.5, 3.2, 11, 1); c.fill();
            roundRect(c, 9.3, 2.5, 3.2, 11, 1); c.fill();
            break;
        case "next":
            c.beginPath(); c.moveTo(1.5, 3); c.lineTo(8, 8); c.lineTo(1.5, 13); c.closePath(); c.fill();
            c.beginPath(); c.moveTo(8, 3); c.lineTo(14.5, 8); c.lineTo(8, 13); c.closePath(); c.fill();
            break;
        case "prev":
            c.beginPath(); c.moveTo(14.5, 3); c.lineTo(8, 8); c.lineTo(14.5, 13); c.closePath(); c.fill();
            c.beginPath(); c.moveTo(8, 3); c.lineTo(1.5, 8); c.lineTo(8, 13); c.closePath(); c.fill();
            break;
        case "chevron":
            c.lineWidth = 1.6;
            c.beginPath(); c.moveTo(6, 3.5); c.lineTo(10.5, 8); c.lineTo(6, 12.5); c.stroke();
            break;
        case "check":
            c.lineWidth = 1.8;
            c.beginPath(); c.moveTo(3, 8.5); c.lineTo(6.5, 12); c.lineTo(13, 4.5); c.stroke();
            break;
        case "lock":
            c.lineWidth = 1.4;
            c.beginPath(); c.arc(8, 6.5, 3, Math.PI, 0); c.lineTo(11, 8); c.moveTo(5, 8); c.lineTo(5, 6.5); c.stroke();
            roundRect(c, 3.5, 7.5, 9, 6.5, 1.5); c.fill();
            break;
        case "power":
            c.lineWidth = 1.7;
            c.beginPath(); c.arc(8, 8.8, 5.6, -Math.PI * 0.32, Math.PI * 1.32); c.stroke();
            c.beginPath(); c.moveTo(8, 1.5); c.lineTo(8, 7.5); c.stroke();
            break;
        case "restart":
            c.lineWidth = 1.7;
            c.beginPath(); c.arc(8, 8.5, 5.5, -Math.PI * 0.35, Math.PI * 1.45); c.stroke();
            c.beginPath(); c.moveTo(13.6, 1.8); c.lineTo(13.1, 5.6); c.lineTo(9.3, 5.0); c.stroke();
            break;
        case "logout":
            c.lineWidth = 1.6;
            c.beginPath(); c.moveTo(9, 2.5); c.lineTo(3.5, 2.5); c.lineTo(3.5, 13.5); c.lineTo(9, 13.5); c.stroke();
            c.beginPath(); c.moveTo(7, 8); c.lineTo(14.5, 8); c.moveTo(11.5, 5); c.lineTo(14.5, 8); c.lineTo(11.5, 11); c.stroke();
            break;
        case "ethernet":
            c.lineWidth = 1.4;
            roundRect(c, 5.5, 1.5, 5, 4, 1); c.stroke();
            roundRect(c, 1, 10.5, 5, 4, 1); c.stroke();
            roundRect(c, 10, 10.5, 5, 4, 1); c.stroke();
            c.beginPath(); c.moveTo(8, 5.5); c.lineTo(8, 8); c.moveTo(3.5, 10.5); c.lineTo(3.5, 8);
            c.lineTo(12.5, 8); c.lineTo(12.5, 10.5); c.stroke();
            break;
        case "gauge":   // system indicator (memory, temperature, power)
            c.lineWidth = 1.6;
            c.beginPath(); c.arc(8, 10, 6.2, Math.PI * 0.85, Math.PI * 2.15); c.stroke();
            c.lineWidth = 1.7;
            c.beginPath(); c.moveTo(8, 10); c.lineTo(11, 6.2); c.stroke();
            c.beginPath(); c.arc(8, 10, 1.5, 0, Math.PI * 2); c.fill();
            break;
        case "cup":     // caffeine: cup with steam
            c.lineWidth = 1.5;
            c.beginPath(); c.moveTo(2.5, 6.5); c.lineTo(11, 6.5); c.lineTo(11, 11);
            c.arcTo(11, 14, 8, 14, 2.5); c.lineTo(5.5, 14); c.arcTo(2.5, 14, 2.5, 11, 2.5);
            c.closePath(); c.fill();
            c.beginPath(); c.arc(11.5, 9.3, 2.2, -Math.PI / 2, Math.PI / 2); c.stroke();
            c.lineWidth = 1.2;
            c.beginPath(); c.moveTo(5, 1.5); c.quadraticCurveTo(6.2, 3, 5, 4.6);
            c.moveTo(8.3, 1.5); c.quadraticCurveTo(9.5, 3, 8.3, 4.6); c.stroke();
            break;
        case "sunset":  // Night Shift: half sun over the horizon
            c.beginPath(); c.arc(8, 11, 3.4, Math.PI, 0); c.closePath(); c.fill();
            c.lineWidth = 1.4;
            for (let i = 0; i < 5; i++) {
                const a = Math.PI + i * Math.PI / 4;
                c.beginPath();
                c.moveTo(8 + Math.cos(a) * 5.2, 11 + Math.sin(a) * 5.2);
                c.lineTo(8 + Math.cos(a) * 6.9, 11 + Math.sin(a) * 6.9);
                c.stroke();
            }
            c.beginPath(); c.moveTo(1, 13.5); c.lineTo(15, 13.5); c.stroke();
            break;
        case "contrast":    // increase contrast: circle with the right half filled
            c.lineWidth = 1.5;
            c.beginPath(); c.arc(8, 8, 6, 0, Math.PI * 2); c.stroke();
            c.beginPath(); c.arc(8, 8, 6, -Math.PI / 2, Math.PI / 2); c.closePath(); c.fill();
            break;
        case "bolt":
            c.beginPath();
            c.moveTo(9.5, 1); c.lineTo(3.5, 9); c.lineTo(7.5, 9); c.lineTo(6.5, 15);
            c.lineTo(12.5, 7); c.lineTo(8.5, 7); c.closePath(); c.fill();
            break;
        }
    }

    function roundRect(c, x, y, w, h, r) {
        c.beginPath();
        c.moveTo(x + r, y);
        c.arcTo(x + w, y, x + w, y + h, r);
        c.arcTo(x + w, y + h, x, y + h, r);
        c.arcTo(x, y + h, x, y, r);
        c.arcTo(x, y, x + w, y, r);
        c.closePath();
    }
}
