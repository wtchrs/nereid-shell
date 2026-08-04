import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.configs

Item {
    id: root

    readonly property int criticalThreshold: 15
    readonly property int warningThreshold: 30

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryAvailable: battery.ready && battery.isPresent
    readonly property bool isCharging: battery.state === UPowerDeviceState.Charging
    readonly property bool isFull: battery.state === UPowerDeviceState.FullyCharged
    readonly property double percentage: battery.percentage * 100

    implicitWidth: Config.bar.width
    implicitHeight: container.implicitHeight

    function getIcon() {
        if (!root.batteryAvailable) return " ";
        if (root.isCharging) return "󰂄";
        if (root.isFull) return "";

        const icons = [" ", " ", " ", " ", " "];

        var idx = Math.min(Math.floor(percentage / 20), 4);
        if (percentage > 0 && idx < 0) idx = 0;

        return icons[idx];
    }

    function getColor() {
        if (!root.batteryAvailable) return Config.theme.fgDim;
        if (root.isCharging) return "#a6da95"; // Green
        if (percentage <= root.criticalThreshold) return "#ed8796"; // Red
        if (percentage <= root.warningThreshold) return "#eed49f"; // Yellow
        return Config.theme.fg;
    }

    RowLayout {
        id: container
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        Text {
            id: icon
            text: getIcon()
            color: getColor()
            font.family: Config.font.icon
            font.pixelSize: 14
        }

        Text {
            text: root.batteryAvailable ? `${Math.round(root.percentage)}%` : "--"
            color: getColor()
            font.family: Config.font.text
            font.pixelSize: 14
        }
    }

    MouseArea {
        id: interaction
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }

    BatteryPanel {
        batteryItem: root
        triggerMouseArea: interaction
        battery: root.battery
        batteryIcon: root.getIcon()
        accentColor: root.getColor()
    }
}
