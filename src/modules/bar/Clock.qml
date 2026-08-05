import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.configs

Item {
    id: root

    property date now: new Date()

    implicitWidth: container.width
    implicitHeight: container.height

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: reload()
    }

    Component.onCompleted: {
        reload()
    }

    function reload() {
        root.now = new Date()
    }

    ColumnLayout {
        id: container
        width: Config.bar.width
        spacing: 0

        ClockText {
            id: dateText
            text: Qt.formatDate(root.now, "MMM dd")
        }

        ClockText {
            id: yearText
            text: Qt.formatDate(root.now, "yyyy")
        }

        ClockText {
            id: timeText
            text: Qt.formatTime(
                root.now,
                root.now.getSeconds() % 2 === 0 ? "HH mm" : "HH:mm"
            )
            font.bold: true
        }
    }

    MouseArea {
        id: interaction
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    ClockPanel {
        clockItem: root
        triggerMouseArea: interaction
        now: root.now
    }

    component ClockText: Text {
        color: Config.theme.fg
        font.family: Config.font.text
        font.pixelSize: 13
        Layout.alignment: Qt.AlignCenter
    }
}
