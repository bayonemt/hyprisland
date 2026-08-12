import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property color cRow: "#313244"
    readonly property color cText: "#cdd6f4"
    readonly property color cDim: "#a6adc8"
    readonly property color cAccent: "#89b4fa"
    readonly property string textFont: "JetBrains Mono"

    property int volume: 0
    property bool sinkMuted: false
    property bool micMuted: false
    property bool dndActive: false

    function refresh() {
        probe.running = false;
        probe.running = true;
    }

    Process {
        id: probe
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '[0-9]+(?=%)' | head -1; pactl get-sink-mute @DEFAULT_SINK@ | grep -oP '(yes|no)$'; pactl get-source-mute @DEFAULT_SOURCE@ | grep -oP '(yes|no)$'; makoctl mode"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 3) {
                    const v = parseInt(lines[0]);
                    if (!isNaN(v))
                        root.volume = v;
                    root.sinkMuted = lines[1].trim() === "yes";
                    root.micMuted = lines[2].trim() === "yes";
                }
                root.dndActive = lines.slice(3).some(l => l.trim() === "do-not-disturb");
            }
        }
    }

    function setVolume(v) {
        const pct = Math.round(v);
        root.volume = pct;
        Quickshell.execDetached(["pactl", "set-sink-volume", "@DEFAULT_SINK@", pct + "%"]);
    }

    function toggleSinkMute() {
        root.sinkMuted = !root.sinkMuted;
        Quickshell.execDetached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]);
    }

    function toggleMicMute() {
        root.micMuted = !root.micMuted;
        Quickshell.execDetached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"]);
    }

    function toggleDnd() {
        root.dndActive = !root.dndActive;
        Quickshell.execDetached(["makoctl", "mode", "-t", "do-not-disturb"]);
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: 1500
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }
    onVisibleChanged: if (visible) refresh()

    component QSSlider: Item {
        id: slider
        property real value: 0
        property color accentColor: root.cAccent
        signal moved(real value)
        implicitHeight: 20

        readonly property real fillWidth: (slider.value / 100) * slider.width

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: root.cRow
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: slider.fillWidth
            height: 6
            radius: 3
            color: slider.accentColor
        }
        Rectangle {
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(slider.width - width, slider.fillWidth - width / 2))
            color: slider.accentColor
            border.color: "#1e1e2e"
            border.width: 1
        }
        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            onPressed: mouse => slider._updateFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    slider._updateFromX(mouse.x);
            }
        }
        function _updateFromX(x) {
            const v = Math.max(0, Math.min(100, (x / slider.width) * 100));
            slider.value = v;
            slider.moved(v);
        }
    }

    component QSSwitch: Rectangle {
        id: sw
        property bool checked: false
        property color accentColor: root.cAccent
        signal toggled

        width: 40
        height: 22
        radius: 11
        color: sw.checked ? sw.accentColor : root.cRow
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Rectangle {
            width: 18
            height: 18
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? sw.width - width - 2 : 2
            color: "#1e1e2e"
            Behavior on x {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 20

        Column {
            width: parent.width
            spacing: 8

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.sinkMuted ? "🔇" : "🔊") + "  Volume"
                    color: root.cText
                    font.pixelSize: 13
                    font.family: root.textFont

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleSinkMute()
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.sinkMuted ? "mudo" : root.volume + "%")
                    color: root.cDim
                    font.pixelSize: 12
                    font.family: root.textFont
                }
            }

            QSSlider {
                width: parent.width
                value: root.volume
                onMoved: v => root.setVolume(v)
            }
        }

        Item {
            width: parent.width
            height: 22

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "🎙️  Microfone"
                color: root.cText
                font.pixelSize: 13
                font.family: root.textFont
            }
            QSSwitch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: !root.micMuted
                onToggled: root.toggleMicMute()
            }
        }

        Item {
            width: parent.width
            height: 22

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "🌙  Não perturbar"
                color: root.cText
                font.pixelSize: 13
                font.family: root.textFont
            }
            QSSwitch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.dndActive
                onToggled: root.toggleDnd()
            }
        }
    }
}
