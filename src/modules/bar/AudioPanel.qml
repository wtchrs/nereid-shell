import QtQuick
import QtQuick.Controls
import qs.configs
import qs.components
import qs.modules.bar.state

AnchoredHoverPanel {
    id: root

    layershellNamespace: "quickshell:audio-panel"
    anchorItem: audioItem
    contentItem: panelContent

    property Item audioItem: null
    property bool outputsExpanded: false

    readonly property int visibleOutputCount: Math.min(
        AudioState.sinkOptions.length,
        Config.audioPanel.outputMaxVisibleItems
    )
    readonly property int outputListMaxHeight: Config.audioPanel.outputRowHeight
        * visibleOutputCount
        + Math.max(0, visibleOutputCount - 1) * Config.audioPanel.outputRowSpacing

    onIsShownChanged: {
        if (!isShown)
            outputsExpanded = false
    }

    Rectangle {
        id: panelContent
        implicitWidth: Config.audioPanel.width
        implicitHeight: contentColumn.implicitHeight + Config.audioPanel.padding * 2
        width: implicitWidth
        height: implicitHeight
        color: Config.theme.bg
        radius: Config.audioPanel.radius
        border.color: Config.theme.br
        border.width: Config.audioPanel.borderWidth

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
                    duration: Config.audioPanel.showDuration
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: "visible"; to: "hidden"
                NumberAnimation {
                    properties: "x,opacity"
                    duration: Config.audioPanel.hideDuration
                    easing.type: Easing.InCubic
                }
            }
        ]

        Column {
            id: contentColumn
            anchors {
                fill: parent
                margins: Config.audioPanel.padding
            }
            spacing: Config.audioPanel.rowSpacing

            Text {
                width: parent.width
                visible: !AudioState.panelAvailable
                text: AudioState.panelMessage
                color: Config.theme.fgDim
                font.family: Config.font.text
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Item {
                id: outputHeader
                width: parent.width
                implicitHeight: Math.max(
                    outputLabel.implicitHeight,
                    valueLabel.implicitHeight,
                    expandIndicator.implicitHeight
                )
                height: implicitHeight
                visible: AudioState.panelAvailable

                Text {
                    id: outputLabel
                    anchors {
                        left: parent.left
                        leftMargin: 0
                        right: valueLabel.left
                        rightMargin: Config.audioPanel.rowSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    text: AudioState.selectedSink
                        ? `${AudioState.sinkLabel(AudioState.selectedSink)}${
                            AudioState.selectedSink === AudioState.defaultSink ? " (default)" : ""
                        }`
                        : "Audio output"
                    color: Config.theme.fg
                    font.family: Config.font.text
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }

                Text {
                    id: valueLabel
                    anchors {
                        right: expandIndicator.left
                        rightMargin: Config.audioPanel.rowSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    text: AudioState.displayMuted
                        ? "Muted"
                        : `${Math.round(volumeSlider.pressed
                            ? volumeSlider.requestedPercent
                            : AudioState.displayVolume * 100)}%`
                    color: Config.theme.fgDim
                    font.family: Config.font.text
                    font.pixelSize: 14
                }

                Text {
                    id: expandIndicator
                    anchors {
                        right: parent.right
                        rightMargin: 0
                        verticalCenter: parent.verticalCenter
                    }
                    width: 10
                    text: root.outputsExpanded ? "v" : ">"
                    color: AudioState.sinkOptions.length > 1 ? Config.theme.fg : Config.theme.fgDim
                    font.family: Config.font.text
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignRight
                }

                MouseArea {
                    id: headerMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: AudioState.sinkOptions.length > 1
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true

                    onClicked: {
                        if (AudioState.sinkOptions.length > 1)
                            root.outputsExpanded = !root.outputsExpanded
                    }
                }
            }

            Item {
                id: outputListContainer
                width: parent.width
                height: root.outputsExpanded ? root.outputListMaxHeight : 0
                implicitHeight: height
                visible: AudioState.panelAvailable && (root.outputsExpanded || height > 0)
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Flickable {
                    anchors.fill: parent
                    contentHeight: outputListColumn.implicitHeight
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: outputListColumn
                        width: outputListContainer.width
                        spacing: Config.audioPanel.outputRowSpacing

                        Repeater {
                            model: AudioState.sinkOptions

                            delegate: Rectangle {
                                id: outputRow

                                required property var modelData

                                readonly property bool selected: modelData
                                    && modelData.key === AudioState.selectedSinkKey

                                width: outputListColumn.width
                                height: Config.audioPanel.outputRowHeight
                                radius: Math.max(0, Config.audioPanel.radius - 4)
                                color: rowMouse.containsMouse
                                    ? Config.theme.surfaceActive
                                    : (selected ? Config.theme.surface : "transparent")

                                Text {
                                    id: selectedMarker
                                    anchors {
                                        left: parent.left
                                        leftMargin: Config.audioPanel.padding
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: 10
                                    text: outputRow.selected ? ">" : ""
                                    color: Config.theme.fg
                                    font.family: Config.font.text
                                    font.pixelSize: 13
                                }

                                Text {
                                    anchors {
                                        left: selectedMarker.right
                                        leftMargin: Config.audioPanel.rowSpacing
                                        right: parent.right
                                        rightMargin: Config.audioPanel.padding
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: outputRow.modelData ? outputRow.modelData.label : ""
                                    color: outputRow.selected ? Config.theme.fg : Config.theme.fgDim
                                    font.family: Config.font.text
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (outputRow.modelData)
                                            AudioState.selectSinkKey(outputRow.modelData.key)
                                        root.outputsExpanded = false
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Slider {
                id: volumeSlider

                property int requestedPercent: Math.round(AudioState.displayVolume * 100)

                width: parent.width
                visible: AudioState.panelAvailable
                from: 0
                to: 100
                stepSize: 1
                value: pressed ? requestedPercent : Math.round(AudioState.displayVolume * 100)
                implicitHeight: Config.audioPanel.sliderHandleSize
                hoverEnabled: true

                onPressedChanged: {
                    if (pressed) {
                        requestedPercent = Math.round(AudioState.displayVolume * 100)
                    } else {
                        writeTimer.stop()
                        AudioState.setSelectedVolume(requestedPercent)
                    }
                }

                onMoved: {
                    requestedPercent = Math.round(value)
                    writeTimer.restart()
                }

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding
                        + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: volumeSlider.hovered
                        ? Config.audioPanel.sliderHandleSize
                        : Config.audioPanel.sliderHeight
                    radius: height / 2
                    color: Config.theme.overlay

                    Behavior on height {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        width: parent.width * volumeSlider.visualPosition
                        height: parent.height
                        radius: parent.radius
                        color: Config.theme.fg
                    }
                }

                handle: Item {}
            }

            Timer {
                id: writeTimer
                interval: Config.audioPanel.volumeDebounceInterval
                repeat: false
                onTriggered: AudioState.setSelectedVolume(volumeSlider.requestedPercent)
            }
        }
    }
}
