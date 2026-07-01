import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.configs

Column {
    id: root

    property var menu: null
    property SystemTrayItem systemTray: null
    property bool showBackRow: false

    readonly property bool hasItems: showBackRow || menuRepeater.count > 0
    readonly property int naturalWidth: {
        let maxWidth = showBackRow ? backRow.implicitWidth : 0
        for (let i = 0; i < menuRepeater.count; i++) {
            const item = menuRepeater.itemAt(i)
            if (item)
                maxWidth = Math.max(maxWidth, item.implicitWidth)
        }
        return maxWidth
    }

    signal submenuRequested(var menuHandle)
    signal backRequested()
    signal leafTriggered()

    spacing: Config.trayMenu.itemSpacing

    QsMenuOpener {
        id: menuOpener

        menu: root.systemTray ? root.systemTray.menu : root.menu
    }

    TrayMenuRow {
        id: backRow

        width: parent.width
        visible: root.showBackRow
        backRow: true

        onBackRequested: root.backRequested()
    }

    Repeater {
        id: menuRepeater

        model: menuOpener.children
        delegate: TrayMenuRow {
            width: parent.width
            menuEntry: modelData

            onSubmenuRequested: menuHandle => root.submenuRequested(menuHandle)
            onLeafTriggered: root.leafTriggered()
        }
    }
}
