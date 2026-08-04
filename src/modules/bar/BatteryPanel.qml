import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.configs
import qs.components

AnchoredHoverPanel {
    id: root

    layershellNamespace: "quickshell:panel"
    anchorItem: batteryItem
    contentItem: panelContent

    property Item batteryItem: null
    property var battery: null
    property string batteryIcon: ""
    property color accentColor: Config.theme.fg

    readonly property bool informationAvailable:
        battery && battery.ready && battery.isPresent
    readonly property bool usesTimeToFull: battery
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge)
    readonly property real remainingTime: !informationAvailable
        ? 0
        : (usesTimeToFull ? battery.timeToFull : battery.timeToEmpty)

    function stateLabel(state) {
        switch (state) {
        case UPowerDeviceState.Charging: return "Charging";
        case UPowerDeviceState.Discharging: return "Discharging";
        case UPowerDeviceState.Empty: return "Empty";
        case UPowerDeviceState.FullyCharged: return "Fully charged";
        case UPowerDeviceState.PendingCharge: return "Pending charge";
        case UPowerDeviceState.PendingDischarge: return "Pending discharge";
        default: return "Unknown";
        }
    }

    function formatDuration(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);

        if (hours > 0)
            return `${hours}h ${minutes}m`;

        return `${minutes}m`;
    }

    function formatEnergy() {
        if (!informationAvailable)
            return "";

        return `${battery.energy.toFixed(1)} / ${battery.energyCapacity.toFixed(1)} Wh`;
    }

    function formatRate() {
        if (!informationAvailable)
            return "";

        const rate = battery.changeRate;

        if (rate > 0)
            return `Charging at ${rate.toFixed(1)} W`;
        if (rate < 0)
            return `Discharging at ${Math.abs(rate).toFixed(1)} W`;

        return "0.0 W";
    }

    component DetailRow: Item {
        required property string label
        required property string value

        implicitHeight: Math.max(detailLabel.implicitHeight, detailValue.implicitHeight)

        Text {
            id: detailLabel
            anchors {
                left: parent.left
                right: detailValue.left
                rightMargin: Config.batteryPanel.rowSpacing
                verticalCenter: parent.verticalCenter
            }
            text: parent.label
            color: Config.theme.fgDim
            font.family: Config.font.text
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Text {
            id: detailValue
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            text: parent.value
            color: Config.theme.fg
            font.family: Config.font.text
            font.pixelSize: 14
        }
    }

    Rectangle {
        id: panelContent
        implicitWidth: Config.batteryPanel.width
        implicitHeight: contentColumn.implicitHeight + Config.batteryPanel.padding * 2
        width: implicitWidth
        height: implicitHeight
        color: Config.theme.bg
        radius: Config.batteryPanel.radius
        border.color: Config.theme.br
        border.width: Config.batteryPanel.borderWidth

        states: [
            State {
                name: "visible"
                when: root.isShown
                PropertyChanges { target: panelContent; opacity: 1; x: borderMargin }
            },
            State {
                name: "hidden"
                when: !root.isShown
                PropertyChanges { target: panelContent; opacity: 0; x: 0 }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"; to: "visible"
                NumberAnimation {
                    properties: "x,opacity"
                    duration: Config.batteryPanel.showDuration
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: "visible"; to: "hidden"
                NumberAnimation {
                    properties: "x,opacity"
                    duration: Config.batteryPanel.hideDuration
                    easing.type: Easing.InCubic
                }
            }
        ]

        Column {
            id: contentColumn
            anchors {
                fill: parent
                margins: Config.batteryPanel.padding
            }
            spacing: Config.batteryPanel.rowSpacing

            Text {
                width: parent.width
                visible: !root.informationAvailable
                text: "Battery information unavailable"
                color: Config.theme.fgDim
                font.family: Config.font.text
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            RowLayout {
                width: parent.width
                visible: root.informationAvailable
                spacing: Config.batteryPanel.rowSpacing

                Text {
                    text: root.batteryIcon
                    color: root.accentColor
                    font.family: Config.font.icon
                    font.pixelSize: 20
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Battery"
                        color: Config.theme.fg
                        font.family: Config.font.text
                        font.pixelSize: 14
                    }

                    Text {
                        text: root.informationAvailable
                            ? root.stateLabel(root.battery.state)
                            : ""
                        color: Config.theme.fgDim
                        font.family: Config.font.text
                        font.pixelSize: 12
                    }
                }

                Text {
                    text: root.informationAvailable
                        ? `${Math.round(root.battery.percentage * 100)}%`
                        : ""
                    color: root.accentColor
                    font.family: Config.font.text
                    font.pixelSize: 18
                }
            }

            DetailRow {
                width: parent.width
                visible: root.informationAvailable && root.remainingTime > 0
                label: root.usesTimeToFull ? "Time to full" : "Time to empty"
                value: root.formatDuration(root.remainingTime)
            }

            DetailRow {
                width: parent.width
                visible: root.informationAvailable
                label: "Energy"
                value: root.formatEnergy()
            }

            DetailRow {
                width: parent.width
                visible: root.informationAvailable
                label: "Rate"
                value: root.formatRate()
            }
        }
    }
}
