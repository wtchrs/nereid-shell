import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property string name
    property var controller: null

    readonly property string sysfsPath: `/sys/class/backlight/${root.name}`
    property string type: ""
    property bool typeLoaded: false
    property int brightnessRaw: -1
    property int actualBrightnessRaw: -1
    property int maxBrightnessRaw: -1
    readonly property int percent: {
        if (!root.valid)
            return 0

        return Math.max(0, Math.min(100, Math.round((root.brightnessRaw / root.maxBrightnessRaw) * 100)))
    }
    readonly property bool valid: root.brightnessRaw >= 0 && root.maxBrightnessRaw > 0

    function parseRawValue(text) {
        const value = parseInt(String(text || "").trim(), 10)
        return isNaN(value) ? -1 : value
    }

    function refresh() {
        typeFile.reload()
        brightnessFile.reload()
        actualBrightnessFile.reload()
        maxBrightnessFile.reload()
    }

    function updateType(text) {
        root.type = String(text || "").trim()
        root.typeLoaded = true
        if (root.controller)
            root.controller.deviceMetadataChanged()
    }

    Component.onCompleted: root.refresh()

    property var typeFile: FileView {
        path: `${root.sysfsPath}/type`
        watchChanges: true
        printErrors: false
        onLoaded: root.updateType(root.typeFile.text())
        onTextChanged: root.updateType(root.typeFile.text())
        onLoadFailed: root.updateType("")
        onFileChanged: root.typeFile.reload()
    }

    property var brightnessFile: FileView {
        path: `${root.sysfsPath}/brightness`
        watchChanges: true
        printErrors: false
        onLoaded: root.brightnessRaw = root.parseRawValue(root.brightnessFile.text())
        onTextChanged: root.brightnessRaw = root.parseRawValue(root.brightnessFile.text())
        onLoadFailed: root.brightnessRaw = -1
        onFileChanged: root.brightnessFile.reload()
    }

    property var actualBrightnessFile: FileView {
        path: `${root.sysfsPath}/actual_brightness`
        watchChanges: true
        printErrors: false
        onLoaded: root.actualBrightnessRaw = root.parseRawValue(root.actualBrightnessFile.text())
        onTextChanged: root.actualBrightnessRaw = root.parseRawValue(root.actualBrightnessFile.text())
        onLoadFailed: root.actualBrightnessRaw = -1
        onFileChanged: root.actualBrightnessFile.reload()
    }

    property var maxBrightnessFile: FileView {
        path: `${root.sysfsPath}/max_brightness`
        watchChanges: true
        printErrors: false
        onLoaded: root.maxBrightnessRaw = root.parseRawValue(root.maxBrightnessFile.text())
        onTextChanged: root.maxBrightnessRaw = root.parseRawValue(root.maxBrightnessFile.text())
        onLoadFailed: root.maxBrightnessRaw = -1
        onFileChanged: root.maxBrightnessFile.reload()
    }
}
