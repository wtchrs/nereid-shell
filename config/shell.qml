//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.launcher
import qs.modules.wallpaper
import qs.niri

ShellRoot {
    id: root
    property color color: "#FF000000"

    function focusedWorkspaceOutputName() {
        const workspaces = Array.isArray(NiriEventStream.workspaces)
            ? NiriEventStream.workspaces
            : []
        const focused = workspaces.find(ws => ws && !!ws.is_focused)
        return focused && focused.output ? String(focused.output) : ""
    }

    function screenName(screen) {
        return screen && screen.name ? String(screen.name) : ""
    }

    function launcherScopes() {
        const instances = screenVariants ? (screenVariants.instances || []) : []
        const scopes = []
        const count = instances.length || 0

        for (let i = 0; i < count; i++) {
            const scope = instances[i]
            if (scope && scope.outputName && scope.launcher)
                scopes.push(scope)
        }

        return scopes
    }

    function closeLaunchers() {
        const scopes = root.launcherScopes()
        for (let i = 0; i < scopes.length; i++)
            scopes[i].launcher.visible = false
    }

    function firstOutputName() {
        const scopes = root.launcherScopes()
        return scopes.length > 0 ? String(scopes[0].outputName) : ""
    }

    function hasVisibleLauncher() {
        const scopes = root.launcherScopes()
        for (let i = 0; i < scopes.length; i++) {
            if (scopes[i].launcher.visible)
                return true
        }
        return false
    }

    function toggleLauncherForOutput(outputName) {
        let targetOutput = outputName || ""

        if (targetOutput === "") {
            if (root.hasVisibleLauncher()) {
                console.warn("appLauncher: focused workspace output unavailable; closing visible launcher")
                root.closeLaunchers()
                return
            }

            targetOutput = root.firstOutputName()
            if (targetOutput !== "")
                console.warn("appLauncher: focused workspace output unavailable; falling back to first screen:", targetOutput)
        }

        let matched = false
        const scopes = root.launcherScopes()
        for (let i = 0; i < scopes.length; i++) {
            const scope = scopes[i]
            const ownOutput = String(scope.outputName || "")
            const isTarget = targetOutput !== "" && ownOutput === targetOutput
            if (isTarget)
                matched = true

            scope.launcher.visible = isTarget ? !scope.launcher.visible : false
        }

        if (!matched && targetOutput !== "") {
            console.warn("appLauncher: no launcher matched output:", targetOutput)
            root.closeLaunchers()
        }
    }

    IpcHandler {
        target: "appLauncher"

        function toggle(): void {
            root.toggleLauncherForOutput(root.focusedWorkspaceOutputName())
        }

        function close(): void {
            root.closeLaunchers()
        }
    }

    Variants {
        id: screenVariants
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property ShellScreen modelData

            readonly property string outputName: root.screenName(screenScope.modelData)
            readonly property var launcher: appLauncher

            Backdrop { screen: modelData }
            Wallpaper { screen: modelData }
            BarStandalone { screen: modelData }
            Launcher { id: appLauncher; screen: modelData }
        }
    }
}
