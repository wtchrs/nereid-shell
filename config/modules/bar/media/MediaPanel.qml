import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.configs
import qs.modules.bar.state

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:media-panel"

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    aboveWindows: true
    color: "transparent"

    anchors {
        left: true
        top: true
    }

    property Item mediaItem: null
    property MouseArea triggerMouseArea: null

    readonly property bool containsMouse:
        (triggerMouseArea && triggerMouseArea.containsMouse) || panelMouseArea.containsMouse
    readonly property bool isShown: containsMouse && MediaState.players.length > 0
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
        if (!mediaItem || !mediaItem.QsWindow || !mediaItem.QsWindow.window)
            return

        const parentWindow = mediaItem.QsWindow.window
        if (!parentWindow.screen)
            return

        root.screen = parentWindow.screen

        const origin = windowOriginInScreen(parentWindow)
        const itemRect = parentWindow.itemRect(mediaItem)
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
        target: mediaItem

        function onXChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onYChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onWidthChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onHeightChanged() { if (root.isShown || root.visible) root.updatePosition() }
    }

    Connections {
        target: mediaItem && mediaItem.QsWindow ? mediaItem.QsWindow.window : null

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
            implicitWidth: Config.mediaPanel.width
            implicitHeight: contentColumn.implicitHeight + Config.mediaPanel.padding * 2
            width: implicitWidth
            height: implicitHeight
            color: Config.theme.bg
            radius: Config.mediaPanel.radius
            border.color: Config.theme.br
            border.width: Config.mediaPanel.borderWidth

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
                        duration: Config.mediaPanel.showDuration
                        easing.type: Easing.OutCubic
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    NumberAnimation {
                        properties: "x,opacity"
                        duration: Config.mediaPanel.hideDuration
                        easing.type: Easing.InCubic
                    }
                }
            ]

            Column {
                id: contentColumn
                anchors {
                    fill: parent
                    margins: Config.mediaPanel.padding
                }
                spacing: Config.mediaPanel.playerSpacing

                Repeater {
                    model: MediaState.players

                    delegate: MediaRow {
                        width: contentColumn.width
                        panelVisible: root.isShown
                    }
                }
            }
        }
    }
}
