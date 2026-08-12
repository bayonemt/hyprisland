import QtQuick

Rectangle {
    id: root

    color: "#1e1e2e"
    border.color: "#181825"
    border.width: 2
    radius: 10

    implicitWidth: 300
    implicitHeight: popupColumn.implicitHeight + 24

    // ── Theme (Catppuccin Mocha, matching waybar's #clock) ──
    readonly property color cBackground: "#1e1e2e"
    readonly property color cRow:        "#313244"
    readonly property color cText:       "#cdd6f4"
    readonly property color cDim:        "#6c7086"
    readonly property color cAccent:     "#fab387"

    readonly property string textFont: "JetBrains Mono"

    readonly property var monthNames: [
        "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
        "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
    ]
    readonly property var weekdayNames: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]

    readonly property var today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function goPrevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear -= 1; }
        else viewMonth -= 1;
    }

    function goNextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear += 1; }
        else viewMonth += 1;
    }

    function goToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    // Builds a 42-cell grid (6 weeks x 7 days), including padding days
    // from the previous/next month so the grid is always fully filled.
    readonly property var gridDays: {
        const firstWeekday = new Date(viewYear, viewMonth, 1).getDay();
        const totalDays = daysInMonth(viewYear, viewMonth);
        const prevTotalDays = daysInMonth(viewMonth === 0 ? viewYear - 1 : viewYear, viewMonth === 0 ? 11 : viewMonth - 1);

        const cells = [];
        for (let i = 0; i < firstWeekday; i++) {
            cells.push({ day: prevTotalDays - firstWeekday + i + 1, current: false });
        }
        for (let d = 1; d <= totalDays; d++) {
            cells.push({ day: d, current: true });
        }
        while (cells.length < 42) {
            cells.push({ day: cells.length - firstWeekday - totalDays + 1, current: false });
        }
        return cells;
    }

    function isToday(day, current) {
        return current
            && viewYear === today.getFullYear()
            && viewMonth === today.getMonth()
            && day === today.getDate();
    }

    Column {
        id: popupColumn
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
        spacing: 8

        // ── Header: month/year + navigation ──
        Item {
            width: parent.width
            height: 28

            component NavButton: Rectangle {
                id: navBtn
                property string icon: ""
                signal clicked()
                width: 28; height: 28; radius: 8
                color: navMouse.containsMouse ? root.cRow : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: navBtn.icon
                    font.pixelSize: 15
                    font.bold: true
                    font.family: root.textFont
                    color: root.cText
                }
                MouseArea {
                    id: navMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: navBtn.clicked()
                }
            }

            NavButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: "‹"
                onClicked: root.goPrevMonth()
            }

            Text {
                anchors.centerIn: parent
                text: root.monthNames[root.viewMonth] + " " + root.viewYear
                font.pixelSize: 14
                font.bold: true
                font.family: root.textFont
                color: root.cAccent

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToday()
                }
            }

            NavButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "›"
                onClicked: root.goNextMonth()
            }
        }

        // ── Weekday header ──
        Grid {
            width: parent.width
            columns: 7
            Repeater {
                model: root.weekdayNames
                Text {
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.textFont
                    color: root.cDim
                }
            }
        }

        // ── Day grid ──
        Grid {
            id: dayGrid
            width: parent.width
            columns: 7
            rowSpacing: 2
            columnSpacing: 0

            Repeater {
                model: root.gridDays
                Item {
                    width: dayGrid.width / 7
                    height: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26; height: 26
                        radius: 13
                        color: root.isToday(modelData.day, modelData.current)
                            ? root.cAccent
                            : (dayMouse.containsMouse ? root.cRow : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            font.pixelSize: 12
                            font.family: root.textFont
                            font.bold: root.isToday(modelData.day, modelData.current)
                            color: {
                                if (root.isToday(modelData.day, modelData.current)) return "#1e1e2e";
                                if (!modelData.current) return root.cDim;
                                return root.cText;
                            }
                        }
                    }

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }
}
