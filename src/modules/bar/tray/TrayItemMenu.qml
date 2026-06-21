import QtQuick
import QtQuick.Layouts
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
    readonly property int windowWidth: menuColumn.implicitWidth >= 150 ? menuColumn.implicitWidth : 150

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
        implicitHeight: menuColumn.implicitHeight + 10
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
            anchors.margins: 5
            spacing: 2

            QsMenuOpener {
                id: menuOpener
                menu: root.systemTray ? root.systemTray.menu : null
            }

            Repeater {
                model: menuOpener.children
                delegate: Rectangle {
                    width: parent.width
                    height: modelData.isSeparator ? 1 : 24
                    color: itemMouseArea.containsMouse ? "#444" : "transparent"

                    Rectangle {
                        visible: modelData.isSeparator
                        anchors.fill: parent
                        color: Config.theme.br
                    }

                    Item {
                        visible: !modelData.isSeparator
                        anchors.fill: parent
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 5

                            Item {
                                width: 16
                                height: 16
                                visible: modelData.icon
                                Image {
                                    source: modelData.icon
                                    width: 16
                                    height: 16
                                }
                            }

                            Text {
                                text: modelData.text
                                color: modelData.enabled ? Config.theme.fg : Config.theme.fgDim
                                Layout.fillWidth: true
                            }
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
