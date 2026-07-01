import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.configs

Item {
    id: root
    implicitWidth: Config.bar.width
    implicitHeight: container.implicitHeight
    visible: trayRepeater.count > 0

    ColumnLayout {
        id: container
        spacing: 5

        Repeater {
            id: trayRepeater

            model: SystemTray.items
            delegate: TrayItem {
                id: trayItem
                systemTray: modelData

                onHoveredChanged: {
                    if (hovered) {
                        sharedMenu.showFor(trayItem, trayItem.iconMouseAreaRef, trayItem.systemTray)
                    }
                }
            }
        }
    }

    TrayItemMenu {
        id: sharedMenu
    }
}
