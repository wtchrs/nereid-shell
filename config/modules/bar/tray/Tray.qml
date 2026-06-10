import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.configs
import ".."

Item {
    id: root
    implicitWidth: Config.bar.width
    implicitHeight: container.implicitHeight

    required property var barWindow
    property Item activeTrayItem: null
    property MouseArea activeIconMouseArea: null

    ColumnLayout {
        id: container
        spacing: 5

        Network {
            anchors {
                horizontalCenter: parent.horizontalCenter
            }
        }

        Repeater {
            model: SystemTray.items
            delegate: TrayItem {
                id: trayItem
                systemTray: modelData

                onHoveredChanged: {
                    if (hovered) {
                        root.activeTrayItem = trayItem
                        root.activeIconMouseArea = trayItem.iconMouseAreaRef
                    }
                }
            }
        }
    }

    TrayItemMenu {
        id: sharedMenu
        trayItem: root.activeTrayItem
        iconMouseArea: root.activeIconMouseArea
    }
}
