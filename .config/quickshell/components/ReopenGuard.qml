// Clicking outside a popup closes it; if that click was on its icon, the
// toggle would open it again. Call closed() when closing it and it won't open if
// canOpen() is false (the same click arrives within 300 ms).
//   ReopenGuard { id: guard }
import QtQuick

QtObject {
    property real _closedAt: 0
    function closed() { _closedAt = Date.now(); }
    function canOpen(): bool { return Date.now() - _closedAt >= 300; }
}
