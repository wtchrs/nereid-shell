import QtQuick
import Quickshell.Io
import qs.configs

Item {
    id: root

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Process {
        id: toggleLauncher
        command: ["qs", "ipc", "call", "appLauncher", "toggle"]
    }

    Text {
        id: icon
        text: "󱗼"
        color: Config.theme.fg
        font.family: Config.font.icon
        font.pixelSize: 24
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!toggleLauncher.running)
                toggleLauncher.running = true
        }
    }
}
