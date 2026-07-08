pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property real volume: 0
    property bool muted: false
    property bool valid: false
    property bool everValid: false
    property bool usePactlFallback: false
    property bool snapshotQueued: false
    property string lastError: ""
    property string selectedSinkKey: ""
    property bool selectionPinned: false

    readonly property bool pipewireReady: Pipewire.ready
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var sinks: {
        const nodes = [...(Pipewire.nodes?.values ?? [])]
        return nodes
            .filter(node => node && node.audio && node.isSink && !node.isStream)
            .sort((left, right) => {
                const labelComparison = root.sinkLabel(left).localeCompare(root.sinkLabel(right))
                if (labelComparison !== 0)
                    return labelComparison

                return root.sinkKey(left).localeCompare(root.sinkKey(right))
            })
    }
    readonly property var sinkOptions: root.sinks.map(node => ({
        key: root.sinkKey(node),
        label: root.sinkLabel(node),
        node: node,
    }))
    readonly property var selectedSink: root.sinkByKey(root.selectedSinkKey)
    readonly property var sinkAudio: {
        const sink = root.selectedSink
        return sink ? sink.audio : null
    }
    readonly property real displayVolume: root.volume
    readonly property bool displayMuted: root.muted
    readonly property bool panelAvailable: !root.usePactlFallback
        && root.pipewireReady && root.sinks.length > 0 && !!root.selectedSink && root.valid
    readonly property string panelMessage: {
        if (root.usePactlFallback)
            return "PipeWire unavailable"
        if (!root.pipewireReady)
            return "PipeWire is not ready"
        if (root.sinks.length === 0)
            return "No audio output devices"
        if (!root.selectedSink || !root.sinkAudio)
            return "No selected output device"
        if (!root.valid)
            return root.lastError || "Audio device is not ready"
        return ""
    }

    function isFiniteNumber(value) {
        return typeof value === "number" && isFinite(value)
    }

    function clampVolume(value) {
        if (!root.isFiniteNumber(value))
            return 0
        return Math.max(0, Math.min(1, value))
    }

    function sinkKey(node) {
        if (!node)
            return ""

        const name = String(node.name || "").trim()
        return name !== "" ? name : String(node.id)
    }

    function sinkLabel(node) {
        if (!node)
            return "Unknown output"

        for (const value of [node.description, node.nickname, node.name, node.id]) {
            const label = String(value || "").trim()
            if (label !== "")
                return label
        }

        return "Unknown output"
    }

    function sinkByKey(key) {
        const normalized = String(key || "")
        if (normalized === "")
            return null

        return root.sinks.find(node => root.sinkKey(node) === normalized) || null
    }

    function sinkOptionIndex(key) {
        const normalized = String(key || "")
        return root.sinkOptions.findIndex(option => option && option.key === normalized)
    }

    function resolveSelectedSink() {
        if (root.usePactlFallback)
            return

        const pinned = root.sinkByKey(root.selectedSinkKey)
        if (root.selectionPinned && pinned)
            return

        if (root.selectionPinned && !pinned)
            root.selectionPinned = false

        const nextSink = root.defaultSink || root.sinks[0] || null
        const nextKey = root.sinkKey(nextSink)
        if (root.selectedSinkKey !== nextKey)
            root.selectedSinkKey = nextKey
    }

    function selectSinkKey(key) {
        const sink = root.sinkByKey(key)
        if (!sink)
            return

        root.selectionPinned = true
        root.selectedSinkKey = root.sinkKey(sink)

        try {
            Pipewire.preferredDefaultAudioSink = sink
        } catch (error) {
            root.lastError = `Failed to select default sink: ${error}`
        }

        root.updateFromPipewire()
    }

    function applyState(nextVolume, nextMuted, source) {
        if (!root.isFiniteNumber(nextVolume)) {
            root.lastError = `Invalid ${source} volume`
            root.valid = false
            return
        }

        root.volume = root.clampVolume(nextVolume)
        root.muted = !!nextMuted
        root.valid = true
        root.everValid = true
        root.lastError = ""
        pipewireProbeTimer.stop()
    }

    function markInvalid(reason) {
        root.valid = false
        if (reason)
            root.lastError = reason
    }

    function switchToPactlFallback(reason) {
        if (root.usePactlFallback)
            return

        root.usePactlFallback = true
        root.lastError = reason || "PipeWire audio probe failed"
        root.valid = false
        pipewireProbeTimer.stop()
        root.scheduleSnapshot()
        if (!pactlSubscribeProc.running)
            pactlSubscribeProc.running = true
    }

    function updateFromPipewire() {
        if (root.usePactlFallback)
            return

        root.resolveSelectedSink()

        const sink = root.selectedSink
        const audio = root.sinkAudio

        if (!root.pipewireReady || !sink || !sink.ready || !audio) {
            root.markInvalid("PipeWire sink is not ready")
            if (!root.everValid)
                pipewireProbeTimer.restart()
            return
        }

        const nextVolume = audio.volume
        if (!root.isFiniteNumber(nextVolume)) {
            root.switchToPactlFallback("PipeWire volume was non-finite")
            return
        }

        root.applyState(nextVolume, audio.muted, "pipewire")
    }

    function setSelectedVolume(percent) {
        if (root.usePactlFallback)
            return

        const audio = root.sinkAudio
        if (!root.selectedSink || !audio) {
            root.markInvalid("PipeWire sink is not ready")
            return
        }

        const nextVolume = root.clampVolume(Number(percent) / 100)
        audio.volume = nextVolume
        root.applyState(nextVolume, audio.muted, "pipewire")
    }

    function stepSelected(deltaPercent) {
        const amount = Math.trunc(Number(deltaPercent))
        if (!isFinite(amount) || amount === 0)
            return

        if (!root.usePactlFallback && root.selectedSink && root.sinkAudio) {
            root.setSelectedVolume(Math.round(root.displayVolume * 100) + amount)
            return
        }

        if (amount > 0)
            root.increase()
        else
            root.decrease()
    }

    function applyPactlSnapshot(output) {
        const text = String(output || "")
        const volumeMatch = text.match(/Volume:[^\n]*?\/\s*([0-9]+)%/)
        const muteMatch = text.match(/Mute:\s+(yes|no)/)

        if (!volumeMatch || !muteMatch) {
            root.markInvalid("Failed to parse pactl snapshot")
            return
        }

        const nextVolume = parseInt(volumeMatch[1], 10) / 100
        root.applyState(nextVolume, muteMatch[1] === "yes", "pactl")
    }

    function scheduleSnapshot() {
        if (pactlSnapshotProc.running) {
            root.snapshotQueued = true
            return
        }

        pactlSnapshotProc.running = true
    }

    function maybeDrainQueuedSnapshot() {
        if (!root.snapshotQueued || pactlSnapshotProc.running)
            return

        root.snapshotQueued = false
        root.scheduleSnapshot()
    }

    function increase() {
        if (!volumeUpProc.running)
            volumeUpProc.running = true
    }

    function decrease() {
        if (!volumeDownProc.running)
            volumeDownProc.running = true
    }

    onPipewireReadyChanged: root.updateFromPipewire()
    onDefaultSinkChanged: root.updateFromPipewire()
    onSinksChanged: root.updateFromPipewire()
    onSelectedSinkChanged: root.updateFromPipewire()

    Component.onCompleted: {
        root.resolveSelectedSink()
        root.updateFromPipewire()
        if (!root.valid)
            pipewireProbeTimer.start()
    }

    PwObjectTracker {
        objects: root.sinks
    }

    Timer {
        id: pipewireProbeTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (!root.usePactlFallback && !root.everValid)
                root.switchToPactlFallback("PipeWire audio probe timed out")
        }
    }

    Timer {
        id: pactlRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.usePactlFallback && !pactlSubscribeProc.running)
                pactlSubscribeProc.running = true
        }
    }

    Connections {
        target: root.selectedSink
        ignoreUnknownSignals: true

        function onReadyChanged() {
            root.updateFromPipewire()
        }
    }

    Connections {
        target: root.sinkAudio
        ignoreUnknownSignals: true

        function onVolumesChanged() {
            root.updateFromPipewire()
        }

        function onMutedChanged() {
            root.updateFromPipewire()
        }
    }

    Process {
        id: pactlSnapshotProc
        command: [
            "sh",
            "-lc",
            "pactl get-sink-volume @DEFAULT_SINK@ && pactl get-sink-mute @DEFAULT_SINK@"
        ]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.applyPactlSnapshot(text)
        }

        onExited: root.maybeDrainQueuedSnapshot()
    }

    Process {
        id: pactlSubscribeProc
        command: ["pactl", "subscribe"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = String(data || "").trim()
                if (line === "")
                    return

                if (
                    line.includes("on sink") ||
                    line.includes("on source") ||
                    line.includes("on server") ||
                    line.includes("on card")
                ) {
                    root.scheduleSnapshot()
                }
            }
        }

        onStarted: root.scheduleSnapshot()

        onExited: {
            if (root.usePactlFallback)
                pactlRestartTimer.restart()
        }
    }

    Process {
        id: volumeUpProc
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1%+"]
        running: false
    }

    Process {
        id: volumeDownProc
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1%-"]
        running: false
    }
}
