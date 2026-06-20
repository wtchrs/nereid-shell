import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.configs
import qs.modules.bar.state

Item {
    id: mediaRow

    required property var modelData
    readonly property var player: modelData
    property bool panelVisible: false

    readonly property bool seekSupported: player && player.canSeek
        && player.positionSupported && player.lengthSupported
        && Number(player.length) > 0
    property real currentPosition: 0
    property real requestedPosition: 0

    readonly property bool hasTrackArt: trackArt.status === Image.Ready

    implicitHeight: trackMetadata.implicitHeight
        + Config.mediaPanel.rowSpacing + positionRow.implicitHeight
        + Config.mediaPanel.rowSpacing + controls.implicitHeight

    function clampPosition(position) {
        const length = Number(player ? player.length : 0)
        const value = Number(position)
        if (!isFinite(length) || length <= 0 || !isFinite(value))
            return 0
        return Math.max(0, Math.min(length, value))
    }

    function formatTime(seconds) {
        const value = Math.max(0, Math.floor(Number(seconds) || 0))
        const hours = Math.floor(value / 3600)
        const minutes = Math.floor((value % 3600) / 60)
        const remainder = value % 60
        const paddedSeconds = String(remainder).padStart(2, "0")
        if (hours > 0)
            return `${hours}:${String(minutes).padStart(2, "0")}:${paddedSeconds}`
        return `${minutes}:${paddedSeconds}`
    }

    function refreshPosition() {
        if (!player || !player.positionSupported)
            return
        currentPosition = clampPosition(player.position)
    }

    Component.onCompleted: refreshPosition()

    Timer {
        interval: Config.mediaPanel.positionRefreshInterval
        repeat: true
        running: mediaRow.panelVisible && !positionSlider.pressed && mediaRow.player
            && mediaRow.player.isPlaying && mediaRow.player.positionSupported
        onTriggered: mediaRow.refreshPosition()
    }

    Connections {
        target: mediaRow.player

        function onPositionChanged() {
            if (!positionSlider.pressed)
                mediaRow.refreshPosition()
        }

        function onTrackChanged() {
            if (!positionSlider.pressed)
                mediaRow.refreshPosition()
        }
    }

    Item {
        id: trackMetadata
        width: parent.width
        implicitHeight: metadataText.implicitHeight

        Column {
            id: metadataText
            anchors {
                left: parent.left
                right: trackArtContainer.visible ? trackArtContainer.left : parent.right
                rightMargin: trackArtContainer.visible ? Config.mediaPanel.thumbnailSpacing : 0
            }
            spacing: Config.mediaPanel.rowSpacing

            Text {
                width: parent.width
                text: mediaRow.player && mediaRow.player.identity
                    ? mediaRow.player.identity
                    : (mediaRow.player && mediaRow.player.desktopEntry
                        ? mediaRow.player.desktopEntry
                        : "Media player")
                color: Config.theme.fgDim
                font.family: Config.font.text
                font.pixelSize: Config.mediaPanel.appNamePixelSize
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: mediaRow.player && mediaRow.player.trackTitle
                    ? mediaRow.player.trackTitle
                    : "Unknown title"
                color: Config.theme.fg
                font.family: Config.font.text
                font.pixelSize: Config.mediaPanel.trackPixelSize
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: mediaRow.player && mediaRow.player.trackArtist
                    ? mediaRow.player.trackArtist
                    : "Unknown artist"
                color: Config.theme.fgDim
                font.family: Config.font.text
                font.pixelSize: Config.mediaPanel.detailPixelSize
                elide: Text.ElideRight
            }
        }

        Item {
            id: trackArtContainer
            anchors.right: parent.right
            width: metadataText.implicitHeight
            height: width
            visible: mediaRow.hasTrackArt

            Image {
                id: trackArt
                anchors.fill: parent
                source: mediaRow.player && mediaRow.player.trackArtUrl
                    ? mediaRow.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectFit
            }
        }
    }

    Item {
        id: positionRow
        anchors {
            top: trackMetadata.bottom
            topMargin: Config.mediaPanel.rowSpacing
            left: parent.left
            right: parent.right
        }
        implicitHeight: positionSlider.implicitHeight
            + Config.mediaPanel.rowSpacing + positionLabels.implicitHeight

        Slider {
            id: positionSlider
            width: parent.width
            from: 0
            to: Math.max(1, Number(mediaRow.player ? mediaRow.player.length : 0))
            enabled: mediaRow.seekSupported
            value: pressed ? mediaRow.requestedPosition : mediaRow.currentPosition
            implicitHeight: Config.mediaPanel.sliderHandleSize
            hoverEnabled: true

            onPressedChanged: {
                if (pressed) {
                    mediaRow.refreshPosition()
                    mediaRow.requestedPosition = mediaRow.currentPosition
                    MediaState.setActiveMedia(mediaRow.player)
                } else {
                    seekTimer.stop()
                    MediaState.seekTo(mediaRow.player, mediaRow.requestedPosition)
                    mediaRow.refreshPosition()
                }
            }

            onMoved: {
                mediaRow.requestedPosition = value
                seekTimer.restart()
            }

            background: Rectangle {
                x: positionSlider.leftPadding
                y: positionSlider.topPadding
                    + positionSlider.availableHeight / 2 - height / 2
                width: positionSlider.availableWidth
                height: positionSlider.hovered
                    ? Config.mediaPanel.sliderHandleSize
                    : Config.mediaPanel.sliderHeight
                radius: height / 2
                color: Config.theme.overlay

                Behavior on height {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    width: parent.width * positionSlider.visualPosition
                    height: parent.height
                    radius: parent.radius
                    color: Config.theme.fg
                }
            }

            handle: Item {}
        }

        RowLayout {
            id: positionLabels
            anchors {
                top: positionSlider.bottom
                topMargin: Config.mediaPanel.rowSpacing
                left: parent.left
                right: parent.right
            }

            Text {
                id: elapsedLabel
                text: mediaRow.seekSupported
                    ? mediaRow.formatTime(positionSlider.pressed
                        ? mediaRow.requestedPosition : mediaRow.currentPosition)
                    : "--:--"
                color: Config.theme.fgDim
                font.family: Config.font.text
                font.pixelSize: Config.mediaPanel.detailPixelSize
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }

            Text {
                id: totalLabel
                text: mediaRow.seekSupported
                    ? mediaRow.formatTime(mediaRow.player.length)
                    : "--:--"
                color: Config.theme.fgDim
                font.family: Config.font.text
                font.pixelSize: Config.mediaPanel.detailPixelSize
            }
        }
    }

    Row {
        id: controls
        anchors {
            top: positionRow.bottom
            topMargin: Config.mediaPanel.rowSpacing
            horizontalCenter: parent.horizontalCenter
        }
        spacing: Config.mediaPanel.controlSpacing

        ControlButton {
            player: mediaRow.player
            icon: "󰒮"
            enabled: mediaRow.player && mediaRow.player.canGoPrevious
            onClicked: MediaState.previous(mediaRow.player)
        }

        ControlButton {
            player: mediaRow.player
            icon: mediaRow.player && mediaRow.player.isPlaying ? "󰏤" : "󰐊"
            enabled: mediaRow.player && mediaRow.player.canTogglePlaying
            onClicked: MediaState.togglePlaying(mediaRow.player)
        }

        ControlButton {
            player: mediaRow.player
            icon: "󰒭"
            enabled: mediaRow.player && mediaRow.player.canGoNext
            onClicked: MediaState.next(mediaRow.player)
        }
    }

    Timer {
        id: seekTimer
        interval: Config.mediaPanel.seekDebounceInterval
        repeat: false
        onTriggered: MediaState.seekTo(mediaRow.player, mediaRow.requestedPosition)
    }
}
