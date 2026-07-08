import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.configs
import qs.modules.bar.state

Item {
    id: root

    readonly property var audioState: AudioState

    implicitWidth: Config.bar.width
    implicitHeight: container.implicitHeight

    RowLayout {
        id: container
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Text {
            id: volumeIcon
            text: {
                if (!root.audioState.everValid) return "󰕾";
                if (root.audioState.displayMuted || root.audioState.displayVolume === 0) return "󰝟";
                if (root.audioState.displayVolume < 0.5) return "󰕿";
                return "󰕾";
            }
            color: Config.theme.fg
            font.family: Config.font.icon
            font.pixelSize: 18
        }

        Text {
            text: {
                if (!root.audioState.everValid) return "--";
                return root.audioState.displayMuted ? "Muted" : `${Math.round(root.audioState.displayVolume * 100)}%`;
            }
            color: Config.theme.fg
            font.family: Config.font.text
            font.pixelSize: 14
        }
    }

    MouseArea {
        id: interaction
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onWheel: {
            if (wheel.angleDelta.y === 0)
                return

            root.audioState.stepSelected(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }

    AudioPanel {
        audioItem: root
        triggerMouseArea: interaction
    }
}
