import QtQuick
import qs.configs
import qs.modules.bar.state

Item {
    id: controlButton

    required property var player
    required property string icon
    required property bool enabled

    signal clicked(MouseEvent mouse)

    width: Config.mediaPanel.controlButtonSize
    height: Config.mediaPanel.controlButtonSize

    Text {
        anchors.centerIn: parent
        text: controlButton.icon
        color: controlButton.enabled ? Config.theme.fg : Config.theme.fgDim
        font.family: Config.font.icon
        font.pixelSize: Config.mediaPanel.iconPixelSize
    }

    MouseArea {
        id: controlMouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: controlButton.enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: MediaState.setActiveMedia(controlButton.player)
        onClicked: (mouse) => controlButton.clicked(mouse)
    }
}
