import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.configs
import qs.modules.bar.state

Item {
    id: root

    readonly property var activeDevice: BrightnessState.activeDevice

    implicitWidth: Config.bar.width
    implicitHeight: container.implicitHeight

    // --- Helpers ---

    function getIcon() {
        const icons = [" ", " ", " ", " ", " "];
        const level = root.activeDevice && root.activeDevice.valid ? root.activeDevice.percent : 0;
        var idx = Math.min(Math.floor(level / 20), 4);
        if (level > 0 && idx < 0) idx = 0;
        return icons[idx];
    }

    // --- UI Layout ---

    RowLayout {
        id: container
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Text {
            id: icon
            text: getIcon()
            color: Config.theme.fg
            font.family: Config.font.icon
            font.pixelSize: 14
        }

        Text {
            text: root.activeDevice && root.activeDevice.valid
                ? `${root.activeDevice.percent}%`
                : "--"
            color: Config.theme.fg
            font.family: Config.font.text
            font.pixelSize: 14
        }
    }

    // --- Interaction ---

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onWheel: {
            if (wheel.angleDelta.y === 0)
                return

            BrightnessState.stepActive(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }
}
