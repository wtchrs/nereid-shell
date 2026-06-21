import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.configs
import qs.modules.bar.state

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:brightness-panel"

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    aboveWindows: true
    color: "transparent"

    anchors {
        left: true
        top: true
    }

    property Item brightnessItem: null
    property MouseArea triggerMouseArea: null

    readonly property bool containsMouse:
        (triggerMouseArea && triggerMouseArea.containsMouse) || panelMouseArea.containsMouse
    readonly property bool isShown: containsMouse
    readonly property int borderMargin: Config.border.thickness + Config.border.lineWidth + 2

    BackgroundEffect.blurRegion: panelContent.opacity > 0 ? panelBlurRegion : null

    Region {
        id: panelBlurRegion
        item: panelContent
        radius: panelContent.radius
    }

    visible: panelContent.opacity > 0
    implicitWidth: panelContent.implicitWidth + borderMargin
    implicitHeight: panelContent.implicitHeight

    function windowOriginInScreen(window) {
        if (!window || !window.screen)
            return Qt.point(0, 0)

        const screen = window.screen
        if (("anchors" in window) && ("margins" in window)
                && ("width" in window) && ("height" in window)) {
            const anchors = window.anchors
            const margins = window.margins
            let x = 0
            let y = 0

            if (anchors.left)
                x = margins.left
            else if (anchors.right)
                x = screen.width - window.width - margins.right

            if (anchors.top)
                y = margins.top
            else if (anchors.bottom)
                y = screen.height - window.height - margins.bottom

            return Qt.point(x, y)
        }

        if (("x" in window) && ("y" in window))
            return Qt.point(window.x - screen.x, window.y - screen.y)

        return Qt.point(0, 0)
    }

    function updatePosition() {
        if (!brightnessItem || !brightnessItem.QsWindow || !brightnessItem.QsWindow.window)
            return

        const parentWindow = brightnessItem.QsWindow.window
        if (!parentWindow.screen)
            return

        root.screen = parentWindow.screen

        const origin = windowOriginInScreen(parentWindow)
        const itemRect = parentWindow.itemRect(brightnessItem)
        const width = Math.max(1, Math.floor(root.implicitWidth))
        const height = Math.max(1, Math.floor(root.implicitHeight))

        let x = Math.floor(origin.x + itemRect.x + itemRect.width - 1)
        let y = Math.floor(origin.y + itemRect.y + (itemRect.height - height) / 2)

        const screen = root.screen
        if (screen) {
            x = Math.max(0, Math.min(x, screen.width - width))
            y = Math.max(0, Math.min(y, screen.height - height))
        }

        root.margins.left = x
        root.margins.top = y
    }

    onIsShownChanged: {
        if (isShown)
            updatePosition()
    }

    onImplicitHeightChanged: {
        if (isShown || visible)
            updatePosition()
    }

    Connections {
        target: brightnessItem

        function onXChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onYChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onWidthChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onHeightChanged() { if (root.isShown || root.visible) root.updatePosition() }
    }

    Connections {
        target: brightnessItem && brightnessItem.QsWindow ? brightnessItem.QsWindow.window : null

        function onWindowTransformChanged() {
            if (root.isShown || root.visible)
                root.updatePosition()
        }
    }

    MouseArea {
        id: panelMouseArea
        anchors.fill: parent
        hoverEnabled: true

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
}
