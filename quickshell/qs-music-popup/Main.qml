import QtQuick
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: window

    title: "music-popup"
    color: "transparent"

    implicitWidth: 380
    implicitHeight: content.implicitHeight

    visible: false

    property bool popupVisible: false

    // Read toggle state from a flag file
    Process {
        id: flagReader
        command: ["cat", "/tmp/qs-music-popup-visible"]
        stdout: StdioCollector {
            onStreamFinished: window.popupVisible = (text.trim() === "1")
        }
    }

    Timer {
        id: flagPoller
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            flagReader.running = false;
            flagReader.running = true;
        }
    }

    onPopupVisibleChanged: {
        window.visible = window.popupVisible;
    }

    HubPopup {
        id: content
        anchors.fill: parent
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Quickshell.execDetached(["bash", "-c", "echo 0 > /tmp/qs-music-popup-visible"])
    }
}
