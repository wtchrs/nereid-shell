pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQml
import qs.components
import qs.configs
import qs.modules.bar.state

AnchoredHoverPanel {
    id: root

    layershellNamespace: "quickshell:panel"
    anchorItem: clockItem
    contentItem: panelContent

    property Item clockItem: null
    property date now: new Date()
    property date displayDate: new Date()
    property int requestCycle: 0
    property string hoveredDateKey: ""
    property var hoveredDate: null

    readonly property var locale: Qt.locale()
    readonly property int displayYear: displayDate.getFullYear()
    readonly property int displayMonth: displayDate.getMonth()
    readonly property string hoveredHolidayText: {
        const holidays = HolidayState.holidaysByYear
        if (!holidays || !root.hoveredDate)
            return ""
        return HolidayState.holidaysForDate(root.hoveredDate).join(" · ")
    }

    function resetToCurrentMonth() {
        root.displayDate = new Date(root.now.getFullYear(), root.now.getMonth(), 1)
        root.hoveredDateKey = ""
        root.hoveredDate = null
    }

    function moveMonth(offset) {
        root.displayDate = new Date(
            root.displayYear, root.displayMonth + offset, 1
        )
    }

    function visibleYears() {
        const firstOfMonth = new Date(root.displayYear, root.displayMonth, 1)
        const offset = (firstOfMonth.getDay() - root.locale.firstDayOfWeek + 7) % 7
        const firstCell = new Date(root.displayYear, root.displayMonth, 1 - offset)
        const lastCell = new Date(firstCell)
        lastCell.setDate(firstCell.getDate() + 41)

        return firstCell.getFullYear() === lastCell.getFullYear()
            ? [firstCell.getFullYear()]
            : [firstCell.getFullYear(), lastCell.getFullYear()]
    }

    function requestVisibleYears() {
        if (!root.isShown || root.requestCycle === 0)
            return
        HolidayState.ensureYears(root.visibleYears(), root.requestCycle)
    }

    onIsShownChanged: {
        if (isShown) {
            root.requestCycle = 0
            root.resetToCurrentMonth()
            root.requestCycle = HolidayState.beginOpenCycle()
            root.requestVisibleYears()
        } else {
            root.requestCycle = 0
            root.resetToCurrentMonth()
        }
    }

    onDisplayDateChanged: root.requestVisibleYears()

    Rectangle {
        id: panelContent
        implicitWidth: Config.clockPanel.width
        implicitHeight: contentColumn.implicitHeight + Config.clockPanel.padding * 2
        width: implicitWidth
        height: implicitHeight
        color: Config.theme.bg
        radius: Config.clockPanel.radius
        border.color: Config.theme.br
        border.width: Config.clockPanel.borderWidth

        states: [
            State {
                name: "visible"
                when: root.isShown
                PropertyChanges { target: panelContent; opacity: 1; x: borderMargin }
            },
            State {
                name: "hidden"
                when: !root.isShown
                PropertyChanges { target: panelContent; opacity: 0; x: 0 }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"; to: "visible"
                NumberAnimation {
                    properties: "x,opacity"
                    duration: Config.clockPanel.showDuration
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: "visible"; to: "hidden"
                NumberAnimation {
                    properties: "x,opacity"
                    duration: Config.clockPanel.hideDuration
                    easing.type: Easing.InCubic
                }
            }
        ]

        Column {
            id: contentColumn
            anchors {
                fill: parent
                margins: Config.clockPanel.padding
            }
            spacing: Config.clockPanel.sectionSpacing

            Column {
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: Qt.formatTime(root.now, "HH:mm:ss")
                    color: Config.theme.fg
                    font.family: Config.font.text
                    font.pixelSize: 28
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: root.now.toLocaleDateString(root.locale, Locale.LongFormat)
                    color: Config.theme.fgDim
                    font.family: Config.font.text
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Column {
                width: parent.width
                spacing: Config.clockPanel.rowSpacing

                Item {
                    width: parent.width
                    implicitHeight: Math.max(
                        previousMonth.implicitHeight,
                        monthTitle.implicitHeight,
                        nextMonth.implicitHeight
                    )
                    height: implicitHeight

                    Text {
                        id: previousMonth
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                        width: 32
                        text: "‹"
                        color: previousMouse.containsMouse
                            ? Config.theme.fg : Config.theme.fgDim
                        font.family: Config.font.text
                        font.pixelSize: 22
                        horizontalAlignment: Text.AlignHCenter

                        MouseArea {
                            id: previousMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.moveMonth(-1)
                        }
                    }

                    Text {
                        id: monthTitle
                        anchors.centerIn: parent
                        text: monthGrid.title
                        color: Config.theme.fg
                        font.family: Config.font.text
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        id: nextMonth
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        width: 32
                        text: "›"
                        color: nextMouse.containsMouse
                            ? Config.theme.fg : Config.theme.fgDim
                        font.family: Config.font.text
                        font.pixelSize: 22
                        horizontalAlignment: Text.AlignHCenter

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.moveMonth(1)
                        }
                    }
                }

                Text {
                    id: todayButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Today"
                    color: todayMouse.containsMouse
                        ? Config.theme.fg : Config.theme.fgDim
                    font.family: Config.font.text
                    font.pixelSize: 12

                    MouseArea {
                        id: todayMouse
                        anchors {
                            fill: parent
                            margins: -4
                        }
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetToCurrentMonth()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4

                DayOfWeekRow {
                    id: dayOfWeekRow

                    width: parent.width
                    height: 22
                    locale: root.locale
                    spacing: 0

                    delegate: Text {
                        required property string shortName

                        width: dayOfWeekRow.availableWidth / 7
                        height: dayOfWeekRow.availableHeight
                        text: shortName
                        color: Config.theme.fgDim
                        font.family: Config.font.text
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MonthGrid {
                    id: monthGrid
                    width: parent.width
                    height: Config.clockPanel.dayCellHeight * 6
                    padding: 0
                    spacing: 0
                    month: root.displayMonth
                    year: root.displayYear
                    locale: root.locale

                    delegate: Item {
                        id: dayCell
                        required property var model

                        width: monthGrid.availableWidth / 7
                        height: Config.clockPanel.dayCellHeight
                        readonly property bool inCurrentMonth:
                            model.month === monthGrid.month && model.year === monthGrid.year
                        readonly property string dateKey:
                            HolidayState.dateKey(model.date)
                        readonly property var holidayNames:
                            HolidayState.holidaysForDate(model.date)

                        opacity: inCurrentMonth ? 1 : 0.4

                        Rectangle {
                            width: 24
                            height: 24
                            radius: width / 2
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                verticalCenter: parent.verticalCenter
                                verticalCenterOffset: -2
                            }
                            visible: dayCell.model.today
                            color: Config.theme.surfaceActive
                        }

                        Text {
                            id: dayNumber
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                verticalCenter: parent.verticalCenter
                                verticalCenterOffset: -2
                            }
                            text: monthGrid.locale.toString(dayCell.model.date, "d")
                            color: Config.theme.fg
                            font.family: Config.font.text
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Rectangle {
                            anchors {
                                top: dayNumber.bottom
                                topMargin: 2
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: 4
                            height: 4
                            radius: 2
                            visible: dayCell.holidayNames.length > 0
                            color: Config.clockPanel.holidayColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                            onEntered: {
                                root.hoveredDateKey = dayCell.dateKey
                                root.hoveredDate = dayCell.model.date
                            }
                            onExited: {
                                if (root.hoveredDateKey !== dayCell.dateKey)
                                    return

                                root.hoveredDateKey = ""
                                root.hoveredDate = null
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    height: 18
                    text: root.hoveredHolidayText
                    color: Config.clockPanel.holidayColor
                    font.family: Config.font.text
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
