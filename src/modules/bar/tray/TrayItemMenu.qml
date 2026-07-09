import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.configs
import qs.components

AnchoredHoverPanel {
    id: root

    layershellNamespace: "quickshell:tray-menu"
    anchorItem: trayItem
    triggerMouseArea: iconMouseArea
    contentItem: popupContent

    property Item trayItem: null
    property MouseArea iconMouseArea: null
    property SystemTrayItem systemTray: null
    property SystemTrayItem currentMenuSource: null
    property int menuResetGeneration: 0

    readonly property bool canShowMenu: !!systemTray
        && systemTray.hasMenu
        && !!currentMenuSource
        && rootSection.hasItems
    readonly property int contentNaturalWidth: rootSection.naturalWidth
        + Config.trayMenu.padding * 2
    readonly property int windowWidth: Math.max(
        Config.trayMenu.minWidth,
        Math.min(contentNaturalWidth, Config.trayMenu.maxWidth)
    )
    readonly property int windowHeight: Math.min(
        rootSection.implicitHeight + Config.trayMenu.padding * 2,
        Config.trayMenu.maxHeight
    )

    function resetAccordionState() {
        menuResetGeneration += 1
        if (typeof menuViewport !== "undefined")
            menuViewport.contentY = 0
    }

    function clearMenuState() {
        currentMenuSource = null
        resetAccordionState()
    }

    function resetMenu() {
        clearMenuState()
        if (!systemTray || !systemTray.hasMenu || !systemTray.menu)
            return

        currentMenuSource = systemTray
    }

    function showFor(item, mouseArea, tray) {
        const trayChanged = trayItem !== item || iconMouseArea !== mouseArea || systemTray !== tray

        if (trayChanged)
            clearMenuState()

        trayItem = item
        iconMouseArea = mouseArea
        systemTray = tray

        if (trayChanged && systemTray && systemTray.hasMenu && systemTray.menu)
            currentMenuSource = systemTray

        if (trayItem && iconMouseArea && iconMouseArea.containsMouse) {
            active = true
        }

        if (trayItem && (visible || isShown || (iconMouseArea && iconMouseArea.containsMouse))) {
            updatePosition()
        }
    }

    onContainsMouseChanged: function() {
        if (!containsMouse) {
            active = true
        }
    }

    onTrayItemChanged: {
        if (trayItem && iconMouseArea && iconMouseArea.containsMouse) {
            active = true
        }

        if (trayItem && (visible || isShown || (iconMouseArea && iconMouseArea.containsMouse))) {
            updatePosition()
        }
    }

    onIconMouseAreaChanged: {
        if (trayItem && iconMouseArea && iconMouseArea.containsMouse) {
            active = true
            updatePosition()
        }
    }

    onCanShowMenuChanged: {
        if (canShowMenu && (isShown || visible))
            updatePosition()
    }

    onVisibleChanged: {
        if (!visible && !isShown)
            resetAccordionState()
    }

    Connections {
        target: root.systemTray
        ignoreUnknownSignals: true

        function onHasMenuChanged() { root.resetMenu() }
        function onMenuChanged() { root.resetMenu() }
    }

    Connections {
        target: rootSection

        function onNaturalWidthChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onImplicitHeightChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onHasItemsChanged() { if (root.canShowMenu && (root.isShown || root.visible)) root.updatePosition() }
    }

    Rectangle {
        id: popupContent
        implicitWidth: windowWidth
        implicitHeight: windowHeight
        width: implicitWidth
        height: implicitHeight
        color: Config.theme.bg
        radius: 10
        border.color: Config.theme.br
        border.width: 1

        states: [
            State {
                name: "visible"
                when: root.isShown && root.canShowMenu
                PropertyChanges { target: popupContent; opacity: 1; x: borderMargin }
            },
            State {
                name: "hidden"
                when: !root.isShown || !root.canShowMenu
                PropertyChanges { target: popupContent; opacity: 0; x: 0 }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"; to: "visible"
                NumberAnimation { properties: "x,opacity"; duration: 200; easing.type: Easing.OutCubic }
            },
            Transition {
                from: "visible"; to: "hidden"
                NumberAnimation { properties: "x,opacity"; duration: 150; easing.type: Easing.InCubic }
            }
        ]

        Flickable {
            id: menuViewport

            anchors.fill: parent
            anchors.margins: Config.trayMenu.padding
            contentWidth: width
            contentHeight: rootSection.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            TrayMenuSection {
                id: rootSection

                width: menuViewport.width
                systemTray: root.currentMenuSource
                resetGeneration: root.menuResetGeneration

                onLeafTriggered: root.active = false
            }
        }
    }
}
