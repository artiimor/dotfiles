// Al hacer clic fuera de un popup se cierra; si ese clic era en su icono, el
// toggle lo volvería a abrir. Se llama a closed() al cerrarlo y no se abre si
// canOpen() es false (el mismo clic llega antes de 300 ms).
//   ReopenGuard { id: guard }
import QtQuick

QtObject {
    property real _closedAt: 0
    function closed() { _closedAt = Date.now(); }
    function canOpen(): bool { return Date.now() - _closedAt >= 300; }
}
