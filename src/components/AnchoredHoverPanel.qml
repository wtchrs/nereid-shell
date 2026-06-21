import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.configs

PanelWindow {
    id: root

    property string layershellNamespace: ""
    property Item anchorItem: null
    property MouseArea triggerMouseArea: null
    property Item contentItem: null
    property bool active: true

    default property alias content: panelMouseArea.data

    WlrLayershell.namespace: layershellNamespace

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    aboveWindows: true
    color: "transparent"

    anchors {
        left: true
        top: true
    }

    readonly property bool containsMouse:
        (triggerMouseArea && triggerMouseArea.containsMouse) || panelMouseArea.containsMouse
    readonly property bool isShown: containsMouse && active
    readonly property int borderMargin: Config.border.thickness + Config.border.lineWidth + 2

    BackgroundEffect.blurRegion: contentItem && contentItem.opacity > 0 ? panelBlurRegion : null

    Region {
        id: panelBlurRegion
        item: root.contentItem
        radius: root.contentItem ? root.contentItem.radius : 0
    }

    visible: contentItem && contentItem.opacity > 0
    implicitWidth: contentItem ? contentItem.implicitWidth + borderMargin : 0
    implicitHeight: contentItem ? contentItem.implicitHeight : 0

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
        if (!anchorItem || !anchorItem.QsWindow || !anchorItem.QsWindow.window)
            return

        const parentWindow = anchorItem.QsWindow.window
        if (!parentWindow.screen)
            return

        root.screen = parentWindow.screen

        const origin = windowOriginInScreen(parentWindow)
        const itemRect = parentWindow.itemRect(anchorItem)
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

    onImplicitWidthChanged: {
        if (isShown || visible)
            updatePosition()
    }

    onImplicitHeightChanged: {
        if (isShown || visible)
            updatePosition()
    }

    Connections {
        target: root.anchorItem

        function onXChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onYChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onWidthChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onHeightChanged() { if (root.isShown || root.visible) root.updatePosition() }
    }

    Connections {
        target: root.anchorItem && root.anchorItem.QsWindow
            ? root.anchorItem.QsWindow.window : null

        function onWindowTransformChanged() {
            if (root.isShown || root.visible)
                root.updatePosition()
        }
    }

    MouseArea {
        id: panelMouseArea
        anchors.fill: parent
        hoverEnabled: true
    }
}
