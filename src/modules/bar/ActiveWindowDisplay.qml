import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.configs
import qs.niri

Item {
    id: root
    implicitWidth: Config.bar.width
    implicitHeight: 10
    clip: true

    property var niri: NiriEventStream

    readonly property string outputName: root.QsWindow?.window?.screen?.name || ""

    readonly property var activeWorkspace: {
        const wsAll = (root.niri && Array.isArray(root.niri.workspaces)) ? root.niri.workspaces : []
        if (!root.outputName)
            return null
        return wsAll.find(ws => ws && String(ws.output || "") === root.outputName && !!ws.is_active) || null
    }

    readonly property var activeWindowId: {
        const ws = root.activeWorkspace
        if (!ws) return null
        return ("active_window_id" in ws) ? ws.active_window_id : null
    }

    readonly property var activeWindow: {
        const id = root.activeWindowId
        if (id === null || id === undefined)
            return null

        const wins = (root.niri && Array.isArray(root.niri.windows)) ? root.niri.windows : []
        return wins.find(x => x && x.id === id) || null
    }

    readonly property string resolvedTitle: {
        const w = root.activeWindow
        return (w && w.title !== null && w.title !== undefined) ? String(w.title) : ""
    }

    readonly property string resolvedAppId: {
        const w = root.activeWindow
        return (w && w.app_id !== null && w.app_id !== undefined) ? String(w.app_id) : ""
    }

    readonly property string resolvedIconSource: {
        const appId = root.resolvedAppId
        if (appId === "")
            return ""

        const entry = DesktopEntries.heuristicLookup(appId)
            || DesktopEntries.byId(appId)
            || DesktopEntries.byId(appId + ".desktop")
        const entryIcon = (entry && entry.icon) ? String(entry.icon) : ""
        if (entryIcon !== "") {
            const entryIconPath = Quickshell.iconPath(entryIcon, true)
            if (entryIconPath !== "")
                return entryIconPath
        }

        return Quickshell.iconPath(appId, true)
    }

    // Flicker guard: keep the previous title briefly if the id updates before the windows list.
    property string stableTitle: ""
    property string stableIconSource: ""

    readonly property int iconSize: 20
    readonly property int iconTextGap: 6
    readonly property bool shouldShowTitle: root.stableTitle !== ""
    readonly property bool shouldShowIcon: root.stableIconSource !== ""
    readonly property real iconSlotWidth: root.shouldShowIcon ? root.iconSize + root.iconTextGap : 0
    readonly property real contentWidth: root.shouldShowTitle
        ? Math.min(root.height, root.iconSlotWidth + titleText.implicitWidth)
        : 0

    Timer {
        id: clearDelay
        interval: 180
        repeat: false
        onTriggered: {
            // Still unresolved: clear it.
            if (root.resolvedTitle === "") {
                root.stableTitle = ""
                root.stableIconSource = ""
            }
        }
    }

    onResolvedTitleChanged: {
        if (root.resolvedTitle !== "") {
            root.stableTitle = root.resolvedTitle
            root.stableIconSource = root.resolvedIconSource
            clearDelay.stop()
        } else {
            // No active window: clear immediately.
            if (root.activeWindowId === null || root.activeWindowId === undefined || !root.activeWorkspace) {
                root.stableTitle = ""
                root.stableIconSource = ""
                clearDelay.stop()
            } else {
                // Possible event reordering: delay clearing slightly.
                clearDelay.restart()
            }
        }
    }

    onResolvedIconSourceChanged: {
        if (root.resolvedTitle !== "")
            root.stableIconSource = root.resolvedIconSource
    }

    Item {
        id: titleWrapper
        width: root.width
        implicitHeight: titleContent.width

        states: [
            State {
                name: "empty"
                when: !root.shouldShowTitle
                PropertyChanges { target: titleWrapper; x: -titleWrapper.width }
            },
            State {
                name: "visible"
                when: root.shouldShowTitle
                PropertyChanges { target: titleWrapper; x: 0 }
            }
        ]

        transitions: [
            Transition {
                from: "*"; to: "*"
                SequentialAnimation {
                    NumberAnimation {
                        properties: "x"
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        ]

        Item {
            id: titleContent
            width: root.contentWidth
            height: Math.max(root.shouldShowIcon ? root.iconSize : 0, titleText.implicitHeight)

            transform: [
                Rotation { angle: 90 },
                Translate { x: (root.width + titleContent.height) / 2 }
            ]

            IconImage {
                id: activeWindowIcon
                visible: root.shouldShowIcon
                source: root.stableIconSource
                implicitSize: root.iconSize
                width: root.iconSize
                height: root.iconSize
                y: (parent.height - height) / 2
                asynchronous: true
                smooth: true
                mipmap: true
            }

            Text {
                id: titleText
                text: root.stableTitle

                font.pixelSize: 14
                font.family: Config.font.text
                font.bold: true
                color: Config.theme.fg

                x: root.iconSlotWidth
                y: (parent.height - height) / 2
                width: Math.max(0, parent.width - x)
                height: implicitHeight
                clip: true
                elide: Text.ElideRight
            }
        }
    }
}
