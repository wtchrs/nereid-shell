import QtQuick
import qs.configs
import qs.components
import qs.modules.bar.state

AnchoredHoverPanel {
    id: root

    layershellNamespace: "quickshell:media-panel"
    anchorItem: mediaItem
    contentItem: panelContent
    active: MediaState.players.length > 0

    property Item mediaItem: null

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
