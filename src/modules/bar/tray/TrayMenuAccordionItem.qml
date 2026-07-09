import QtQuick
import qs.configs

Item {
    id: root

    property var menuEntry: null
    property bool expanded: false
    property int resetGeneration: 0

    readonly property bool separator: entryProperty("isSeparator", false)
    readonly property bool entryEnabled: entryProperty("enabled", false)
    readonly property bool hasChildren: entryProperty("hasChildren", false)
    readonly property var submenuMenu: hasChildren ? menuEntry : null
    readonly property bool canOpenSubmenu: entryEnabled && hasChildren && !!submenuMenu
    readonly property int childNaturalWidth: canOpenSubmenu
        && childSectionLoader.item
        ? Config.trayMenu.submenuIndent + childSectionLoader.item.naturalWidth
        : 0
    readonly property int naturalWidth: expanded
        ? Math.max(row.implicitWidth, childNaturalWidth)
        : row.implicitWidth

    implicitHeight: itemColumn.implicitHeight
    height: implicitHeight

    signal toggleRequested(var menuEntry)
    signal leafTriggered()

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

    Column {
        id: itemColumn

        width: parent.width
        spacing: Config.trayMenu.itemSpacing

        TrayMenuRow {
            id: row

            width: parent.width
            menuEntry: root.menuEntry
            expanded: root.expanded

            onSubmenuRequested: root.toggleRequested(root.menuEntry)
            onLeafTriggered: root.leafTriggered()
        }

        Item {
            id: childContainer

            visible: root.canOpenSubmenu && (root.expanded || height > 0)
            width: parent.width
            height: root.expanded && childSectionLoader.item
                ? childSectionLoader.item.implicitHeight
                : 0
            implicitHeight: height
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Config.trayMenu.submenuAnimationDuration
                    easing.type: Easing.OutCubic
                }
            }

            Loader {
                id: childSectionLoader

                x: Config.trayMenu.submenuIndent
                width: Math.max(0, parent.width - x)
                active: root.canOpenSubmenu
                source: Qt.resolvedUrl("TrayMenuSection.qml")

                onLoaded: item.leafTriggered.connect(function() {
                    root.leafTriggered()
                })
            }

            Binding {
                target: childSectionLoader.item
                property: "width"
                value: childSectionLoader.width
                when: childSectionLoader.status === Loader.Ready
            }

            Binding {
                target: childSectionLoader.item
                property: "menu"
                value: root.submenuMenu
                when: childSectionLoader.status === Loader.Ready
            }

            Binding {
                target: childSectionLoader.item
                property: "resetGeneration"
                value: root.resetGeneration
                when: childSectionLoader.status === Loader.Ready
            }
        }
    }
}
