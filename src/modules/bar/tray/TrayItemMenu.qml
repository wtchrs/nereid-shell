import QtQuick
import QtQuick.Controls
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
    property var currentMenuSource: null

    readonly property Item currentPage: menuStack.currentItem
    readonly property bool canShowMenu: !!systemTray
        && systemTray.hasMenu
        && !!currentMenuSource
        && !!currentPage
        && currentPage.hasItems
    readonly property int contentNaturalWidth: (currentPage ? currentPage.naturalWidth : 0)
        + Config.trayMenu.padding * 2
    readonly property int windowWidth: Math.max(
        Config.trayMenu.minWidth,
        Math.min(contentNaturalWidth, Config.trayMenu.maxWidth)
    )

    function resetMenu() {
        menuStack.clear(StackView.Immediate)
        currentMenuSource = null

        if (!systemTray || !systemTray.hasMenu || !systemTray.menu)
            return

        currentMenuSource = systemTray
        menuStack.push(menuPageComponent, {
            "systemTray": systemTray,
            "showBackRow": false
        }, StackView.Immediate)
    }

    function pushMenu(menuHandle, showBackRow, immediate) {
        if (!menuHandle)
            return

        menuStack.push(menuPageComponent, {
            "menu": menuHandle,
            "systemTray": null,
            "showBackRow": showBackRow
        }, immediate ? StackView.Immediate : StackView.Transition)
    }

    function showFor(item, mouseArea, tray) {
        trayItem = item
        iconMouseArea = mouseArea
        systemTray = tray

        resetMenu()

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

    Connections {
        target: root.systemTray
        ignoreUnknownSignals: true

        function onHasMenuChanged() { root.resetMenu() }
        function onMenuChanged() { root.resetMenu() }
    }

    Connections {
        target: root.currentPage

        function onNaturalWidthChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onImplicitHeightChanged() { if (root.isShown || root.visible) root.updatePosition() }
        function onHasItemsChanged() { if (root.canShowMenu && (root.isShown || root.visible)) root.updatePosition() }
    }

    Component {
        id: menuPageComponent

        TrayMenuPage {
            width: menuStack.width

            onSubmenuRequested: menuHandle => root.pushMenu(menuHandle, true, false)
            onBackRequested: {
                if (menuStack.depth > 1)
                    menuStack.pop()
            }
            onLeafTriggered: root.active = false
        }
    }

    Rectangle {
        id: popupContent
        implicitWidth: windowWidth
        implicitHeight: menuStack.implicitHeight + Config.trayMenu.padding * 2
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

        StackView {
            id: menuStack

            anchors.fill: parent
            anchors.margins: Config.trayMenu.padding
            clip: true
            implicitWidth: currentItem ? currentItem.naturalWidth : 0
            implicitHeight: currentItem ? currentItem.implicitHeight : 0

            pushEnter: Transition {
                NumberAnimation { property: "x"; from: menuStack.width; to: 0; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
            }
            pushExit: Transition {
                NumberAnimation { property: "x"; from: 0; to: -menuStack.width / 3; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.OutCubic }
            }
            popEnter: Transition {
                NumberAnimation { property: "x"; from: -menuStack.width / 3; to: 0; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
            }
            popExit: Transition {
                NumberAnimation { property: "x"; from: 0; to: menuStack.width; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.OutCubic }
            }
        }
    }
}
