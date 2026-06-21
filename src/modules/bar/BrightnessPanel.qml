import QtQuick
import QtQuick.Controls
import qs.configs
import qs.components
import qs.modules.bar.state

AnchoredHoverPanel {
    id: root

    layershellNamespace: "quickshell:brightness-panel"
    anchorItem: brightnessItem
    contentItem: panelContent

    property Item brightnessItem: null

    Rectangle {
        id: panelContent
        implicitWidth: Config.brightnessPanel.width
        implicitHeight: contentColumn.implicitHeight + Config.brightnessPanel.padding * 2
        width: implicitWidth
        height: implicitHeight
        color: Config.theme.bg
        radius: Config.brightnessPanel.radius
        border.color: Config.theme.br
        border.width: Config.brightnessPanel.borderWidth

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
                    duration: Config.brightnessPanel.showDuration
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: "visible"; to: "hidden"
                NumberAnimation {
                    properties: "x,opacity"
                    duration: Config.brightnessPanel.hideDuration
                    easing.type: Easing.InCubic
                }
            }
        ]

        Column {
            id: contentColumn
            anchors {
                fill: parent
                margins: Config.brightnessPanel.padding
            }
            spacing: Config.brightnessPanel.deviceSpacing

            Repeater {
                model: BrightnessState.devices

                delegate: Item {
                    id: deviceRow
                    required property var modelData

                    width: contentColumn.width
                    implicitHeight: labelRow.implicitHeight
                        + Config.brightnessPanel.rowSpacing + brightnessSlider.implicitHeight
                    property int requestedPercent: modelData.valid ? modelData.percent : 0

                    Row {
                        id: labelRow
                        width: parent.width
                        spacing: Config.brightnessPanel.rowSpacing

                        Text {
                            width: parent.width - valueLabel.implicitWidth - parent.spacing
                            text: deviceRow.modelData.name
                            color: Config.theme.fg
                            font.family: Config.font.text
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Text {
                            id: valueLabel
                            text: deviceRow.modelData.valid
                                ? `${deviceRow.modelData.percent}%`
                                : "--"
                            color: Config.theme.fgDim
                            font.family: Config.font.text
                            font.pixelSize: 14
                        }
                    }

                    Slider {
                        id: brightnessSlider
                        anchors {
                            top: labelRow.bottom
                            topMargin: Config.brightnessPanel.rowSpacing
                            left: parent.left
                            right: parent.right
                        }
                        from: 0
                        to: 100
                        stepSize: 1
                        enabled: deviceRow.modelData.valid
                        value: pressed ? deviceRow.requestedPercent : deviceRow.modelData.percent
                        implicitHeight: Config.brightnessPanel.sliderHandleSize
                        hoverEnabled: true

                        onPressedChanged: {
                            if (pressed) {
                                deviceRow.requestedPercent = Math.round(deviceRow.modelData.percent)
                                BrightnessState.selectDevice(deviceRow.modelData.name)
                            } else if (writeTimer.running) {
                                writeTimer.stop()
                                BrightnessState.setBrightness(
                                    deviceRow.modelData.name,
                                    deviceRow.requestedPercent
                                )
                            }
                        }

                        onMoved: {
                            deviceRow.requestedPercent = Math.round(value)
                            writeTimer.restart()
                        }

                        background: Rectangle {
                            x: brightnessSlider.leftPadding
                            y: brightnessSlider.topPadding
                                + brightnessSlider.availableHeight / 2 - height / 2
                            width: brightnessSlider.availableWidth
                            height: brightnessSlider.hovered
                                ? Config.brightnessPanel.sliderHandleSize
                                : Config.brightnessPanel.sliderHeight
                            radius: height / 2
                            color: Config.theme.overlay

                            Behavior on height {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Rectangle {
                                width: parent.width * brightnessSlider.visualPosition
                                height: parent.height
                                radius: parent.radius
                                color: Config.theme.fg
                            }
                        }

                        handle: Item {}
                    }

                    Timer {
                        id: writeTimer
                        interval: Config.brightnessPanel.debounceInterval
                        repeat: false
                        onTriggered: BrightnessState.setBrightness(
                            deviceRow.modelData.name,
                            deviceRow.requestedPercent
                        )
                    }
                }
            }
        }
    }
}
