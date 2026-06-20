pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var devices: []
    property string preferredDevice: ""
    property var activeDevice: null
    property bool discoveryQueued: false
    property string discoveryOutput: ""
    property var pendingDeltas: ({})
    property string writeDeviceName: ""
    property int writeDelta: 0
    property int lastExitCode: 0
    property string lastError: ""
    property string writeErrorText: ""
    property string lastDiscoveryError: ""

    function deviceByName(name) {
        const normalized = String(name || "").trim()
        return root.devices.find(device => device && device.name === normalized) || null
    }

    function typeRank(device) {
        switch (String(device.type || "").trim().toLowerCase()) {
        case "firmware": return 0
        case "platform": return 1
        case "raw": return 2
        default: return 3
        }
    }

    function selectPolicyDevice() {
        const candidates = root.devices.slice()
        candidates.sort((left, right) => {
            const rankDifference = root.typeRank(left) - root.typeRank(right)
            if (rankDifference !== 0)
                return rankDifference

            return left.name.localeCompare(right.name)
        })
        return candidates[0] || null
    }

    function resolveActiveDevice() {
        const preferred = root.deviceByName(root.preferredDevice)
        if (preferred) {
            root.activeDevice = preferred
            return
        }

        if (root.activeDevice && root.deviceByName(root.activeDevice.name) === root.activeDevice)
            return

        if (root.devices.some(device => device && !device.typeLoaded)) {
            activeDeviceTimer.restart()
            return
        }

        root.activeDevice = root.selectPolicyDevice()
    }

    function deviceMetadataChanged() {
        if (!root.activeDevice)
            root.resolveActiveDevice()
    }

    function scheduleActiveDeviceResolution() {
        if (!root.activeDevice)
            activeDeviceTimer.restart()
    }

    function selectDevice(name) {
        const device = root.deviceByName(name)
        if (device)
            root.activeDevice = device
    }

    function discoverDevices() {
        if (discoveryProc.running) {
            root.discoveryQueued = true
            return
        }

        root.discoveryQueued = false
        discoveryProc.running = true
    }

    function applyDiscoveryOutput(text) {
        const names = []
        const seen = ({})
        for (const rawLine of String(text || "").split("\n")) {
            const name = String(rawLine || "").trim()
            if (name !== "" && !seen[name]) {
                seen[name] = true
                names.push(name)
            }
        }
        names.sort((left, right) => left.localeCompare(right))

        const existing = ({})
        for (const device of root.devices) {
            if (device)
                existing[device.name] = device
        }

        const nextDevices = []
        for (const name of names) {
            let device = existing[name]
            if (!device)
                device = backlightDeviceComponent.createObject(root, { name: name, controller: root })
            if (device)
                nextDevices.push(device)
            delete existing[name]
        }

        if (root.activeDevice && !seen[root.activeDevice.name])
            root.activeDevice = null

        root.devices = nextDevices

        const pending = Object.assign({}, root.pendingDeltas)
        for (const name in existing)
            delete pending[name]
        root.pendingDeltas = pending

        for (const name in existing)
            existing[name].destroy()

        // Let newly-created devices load their sysfs type before applying the
        // fallback ranking. A preferred device can be selected immediately.
        if (root.deviceByName(root.preferredDevice) || root.activeDevice)
            root.resolveActiveDevice()
        else
            root.scheduleActiveDeviceResolution()
    }

    function stepDevice(name, delta) {
        const device = root.deviceByName(name)
        const amount = Math.trunc(Number(delta))
        if (!device || !isFinite(amount) || amount === 0)
            return

        const pending = Object.assign({}, root.pendingDeltas)
        const nextDelta = (pending[device.name] || 0) + amount
        if (nextDelta === 0)
            delete pending[device.name]
        else
            pending[device.name] = nextDelta
        root.pendingDeltas = pending
        root.startNextWrite()
    }

    function stepActive(delta) {
        if (root.activeDevice)
            root.stepDevice(root.activeDevice.name, delta)
    }

    function startNextWrite() {
        if (writeProc.running)
            return

        const pending = Object.assign({}, root.pendingDeltas)
        const names = Object.keys(pending).sort((left, right) => left.localeCompare(right))
        for (const name of names) {
            const delta = pending[name]
            delete pending[name]
            root.pendingDeltas = pending
            if (!delta)
                continue

            root.writeDeviceName = name
            root.writeDelta = delta
            root.writeErrorText = ""
            root.lastError = ""
            writeProc.running = true
            return
        }

        root.pendingDeltas = pending
    }

    onPreferredDeviceChanged: root.resolveActiveDevice()

    Component.onCompleted: root.discoverDevices()

    Component {
        id: backlightDeviceComponent
        BacklightDevice {}
    }

    Timer {
        id: discoveryTimer
        interval: 3000
        repeat: true
        running: true
        onTriggered: root.discoverDevices()
    }

    Timer {
        id: activeDeviceTimer
        interval: 50
        repeat: false
        onTriggered: root.resolveActiveDevice()
    }

    Process {
        id: discoveryProc
        command: ["find", "/sys/class/backlight", "-mindepth", "1", "-maxdepth", "1", "-printf", "%f\\n"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.discoveryOutput = text
        }

        stderr: StdioCollector {
            onStreamFinished: root.lastDiscoveryError = String(text || "").trim()
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.lastDiscoveryError = ""
                root.applyDiscoveryOutput(root.discoveryOutput)
            } else if (root.lastDiscoveryError === "") {
                root.lastDiscoveryError = `backlight discovery exited with code ${exitCode}`
            }

            if (root.discoveryQueued)
                root.discoverDevices()
        }
    }

    Process {
        id: writeProc
        command: [
            "brightnessctl", "-c", "backlight", "-d", root.writeDeviceName, "set",
            `${Math.abs(root.writeDelta)}%${root.writeDelta >= 0 ? "+" : "-"}`
        ]
        running: false

        stderr: StdioCollector {
            onStreamFinished: root.writeErrorText = String(text || "").trim()
        }

        onExited: (exitCode, exitStatus) => {
            const completedDeviceName = root.writeDeviceName
            root.lastExitCode = exitCode
            if (exitCode !== 0) {
                root.lastError = root.writeErrorText !== ""
                    ? root.writeErrorText
                    : `brightnessctl exited with code ${exitCode}`
            }

            const device = root.deviceByName(completedDeviceName)
            if (device)
                device.refresh()

            root.writeDeviceName = ""
            root.writeDelta = 0
            root.startNextWrite()
        }
    }
}
