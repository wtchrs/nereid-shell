import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.configs

Column {
    id: root

    property var menu: null
    property SystemTrayItem systemTray: null
    property int resetGeneration: 0
    property var expandedEntry: null

    readonly property bool hasItems: menuRepeater.count > 0
    readonly property int naturalWidth: {
        let maxWidth = 0
        for (let i = 0; i < menuRepeater.count; i++) {
            const item = menuRepeater.itemAt(i)
            if (item)
                maxWidth = Math.max(maxWidth, item.naturalWidth)
        }
        return maxWidth
    }

    signal leafTriggered()

    spacing: Config.trayMenu.itemSpacing

    onMenuChanged: expandedEntry = null
    onSystemTrayChanged: expandedEntry = null
    onResetGenerationChanged: expandedEntry = null

    QsMenuOpener {
        id: menuOpener

        menu: root.systemTray ? root.systemTray.menu : root.menu
    }

    Repeater {
        id: menuRepeater

        model: menuOpener.children
        delegate: TrayMenuAccordionItem {
            width: parent.width
            menuEntry: modelData
            expanded: root.expandedEntry === modelData
            resetGeneration: root.resetGeneration

            onToggleRequested: entry => {
                root.expandedEntry = root.expandedEntry === entry ? null : entry
            }
            onLeafTriggered: root.leafTriggered()
        }
    }
}
