import QtQuick

// Password field for a protected Wi‑Fi network. Takes focus when shown;
// on Enter (or submit()) emits submitted(psk) and clears itself.
Rectangle {
    id: f
    property string placeholder: I18n.tr("Password")
    signal submitted(string psk)
    function submit() { submitted(input.text); input.text = ""; }

    implicitHeight: 26
    radius: 6
    color: Theme.tint(0.10)
    border.color: input.activeFocus ? Theme.accent : Theme.tint(0.12)
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 8; anchors.rightMargin: 8
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        color: Theme.text
        font.pointSize: 9.5
        onVisibleChanged: if (visible) forceActiveFocus()
        onAccepted: f.submit()
        Text {
            visible: !input.text.length
            anchors.verticalCenter: parent.verticalCenter
            text: f.placeholder
            color: Theme.dim
            font.pointSize: 9.5
        }
    }
}
