import QtQuick
import qs.configs

Rectangle {
    id: root

    property var menuEntry: null
    property bool expanded: false

    readonly property bool separator: entryProperty("isSeparator", false)
    readonly property bool entryEnabled: entryProperty("enabled", false)
    readonly property bool hasChildren: entryProperty("hasChildren", false)
    readonly property var submenuMenu: hasChildren ? menuEntry : null
    readonly property bool canOpenSubmenu: entryEnabled && hasChildren && !!submenuMenu
    readonly property bool canTriggerLeaf: entryEnabled && !separator && !hasChildren
    readonly property bool clickable: canOpenSubmenu || canTriggerLeaf
    readonly property int indicatorWidth: canOpenSubmenu ? 14 : 0

    signal submenuRequested(var menuHandle)
    signal leafTriggered()

    width: parent ? parent.width : implicitWidth
    implicitWidth: separator ? 0 : itemContent.implicitWidth
    height: separator ? 1 : Config.trayMenu.itemHeight
    color: itemMouseArea.containsMouse && clickable ? "#444" : "transparent"

    function entryProperty(name, fallback) {
        if (!menuEntry)
            return fallback

        try {
            const value = menuEntry[name]
            return value === undefined ? fallback : value
        } catch (error) {
            return fallback
        }
    }

    Rectangle {
        visible: root.separator
        anchors.fill: parent
        color: Config.theme.br
    }

    Item {
        id: itemContent

        visible: !root.separator
        anchors.fill: parent
        implicitWidth: Config.trayMenu.padding
            + Config.trayMenu.iconSize
            + Config.trayMenu.iconGap
            + itemText.implicitWidth
            + (root.indicatorWidth > 0 ? Config.trayMenu.iconGap + root.indicatorWidth : 0)
            + Config.trayMenu.padding

        Item {
            id: iconSlot

            x: Config.trayMenu.padding
            width: Config.trayMenu.iconSize
            height: Config.trayMenu.iconSize
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: root.entryProperty("icon", "")
                visible: !!source
            }
        }

        Text {
            id: itemText

            x: iconSlot.x + iconSlot.width + Config.trayMenu.iconGap
            width: Math.max(0, root.width
                - Config.trayMenu.padding * 2
                - Config.trayMenu.iconSize
                - Config.trayMenu.iconGap
                - (root.indicatorWidth > 0 ? Config.trayMenu.iconGap + root.indicatorWidth : 0))
            height: parent.height
            text: root.entryProperty("text", "")
            color: root.clickable ? Config.theme.fg : Config.theme.fgDim
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        Text {
            visible: root.canOpenSubmenu
            anchors {
                right: parent.right
                rightMargin: Config.trayMenu.padding
                verticalCenter: parent.verticalCenter
            }
            width: root.indicatorWidth
            text: root.expanded ? "v" : ">"
            color: Config.theme.fg
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        id: itemMouseArea

        anchors.fill: parent
        enabled: root.clickable && !root.separator
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true

        onClicked: {
            if (root.canOpenSubmenu) {
                root.submenuRequested(root.submenuMenu)
            } else if (root.canTriggerLeaf) {
                root.menuEntry.triggered()
                root.leafTriggered()
            }
        }
    }
}
