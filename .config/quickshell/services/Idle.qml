// "Cafeína": si está activo, cada barra pone un IdleInhibitor y hypridle no
// apaga ni bloquea la pantalla. Compartido para que todas las pantallas cuadren.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property bool inhibited: false
}
