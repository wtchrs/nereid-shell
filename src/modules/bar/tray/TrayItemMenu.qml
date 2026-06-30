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

    readonly property SystemTrayItem systemTray: trayItem ? trayItem.systemTray : null
    readonly property int contentNaturalWidth: menuColumn.naturalWidth + Config.trayMenu.padding * 2
    readonly property int windowWidth: Math.max(
        Config.trayMenu.minWidth,
        Math.min(contentNaturalWidth, Config.trayMenu.maxWidth)
    )

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

    Rectangle {
        id: popupContent
        implicitWidth: windowWidth
        implicitHeight: menuColumn.implicitHeight + Config.trayMenu.padding * 2
        width: implicitWidth
        height: implicitHeight
        color: Config.theme.bg
        radius: 10
        border.color: Config.theme.br
        border.width: 1

        states: [
            State {
                name: "visible"
                when: root.isShown
                PropertyChanges { target: popupContent; opacity: 1; x: borderMargin }
            },
            State {
                name: "hidden"
                when: !root.isShown
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

        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: Config.trayMenu.padding
            readonly property int naturalWidth: {
                let maxWidth = 0
                for (let i = 0; i < menuRepeater.count; i++) {
                    const item = menuRepeater.itemAt(i)
                    if (item)
                        maxWidth = Math.max(maxWidth, item.implicitWidth)
                }
                return maxWidth
            }
            spacing: Config.trayMenu.itemSpacing

            QsMenuOpener {
                id: menuOpener
                menu: root.systemTray ? root.systemTray.menu : null
            }

            Repeater {
                id: menuRepeater

                model: menuOpener.children
                delegate: Rectangle {
                    id: menuItem

                    width: parent.width
                    implicitWidth: modelData.isSeparator ? 0 : itemContent.implicitWidth
                    height: modelData.isSeparator ? 1 : Config.trayMenu.itemHeight
                    color: itemMouseArea.containsMouse ? "#444" : "transparent"

                    Rectangle {
                        visible: modelData.isSeparator
                        anchors.fill: parent
                        color: Config.theme.br
                    }

                    Item {
                        id: itemContent

                        visible: !modelData.isSeparator
                        anchors.fill: parent
                        implicitWidth: Config.trayMenu.padding
                            + Config.trayMenu.iconSize
                            + Config.trayMenu.iconGap
                            + itemText.implicitWidth
                            + Config.trayMenu.padding

                        Item {
                            id: iconSlot

                            x: Config.trayMenu.padding
                            width: Config.trayMenu.iconSize
                            height: Config.trayMenu.iconSize
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                anchors.fill: parent
                                source: modelData.icon
                                visible: modelData.icon
                            }
                        }

                        Text {
                            id: itemText

                            x: iconSlot.x + iconSlot.width + Config.trayMenu.iconGap
                            width: Math.max(0, menuItem.width
                                - Config.trayMenu.padding * 2
                                - Config.trayMenu.iconSize
                                - Config.trayMenu.iconGap)
                            height: parent.height
                            text: modelData.text || ""
                            color: modelData.enabled ? Config.theme.fg : Config.theme.fgDim
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        enabled: modelData.enabled && !modelData.isSeparator
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            modelData.triggered()
                            root.active = false
                        }
                    }
                }
            }
        }
    }
}
