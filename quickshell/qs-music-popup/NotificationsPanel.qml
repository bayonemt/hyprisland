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

    property var notifications: []
    property var removedIds: []

    function refresh() {
        historyProc.running = false;
        historyProc.running = true;
    }

    function persistRemoved(ids) {
        Quickshell.execDetached(["bash", "-c", "echo '" + ids.join(",") + "' > /tmp/qs-music-popup-notif-cleared"]);
    }

    function clearAll() {
        const merged = root.removedIds.concat(root.notifications.map(n => n.id));
        root.removedIds = merged;
        root.notifications = [];
        root.persistRemoved(merged);
    }

    function removeOne(id) {
        const merged = root.removedIds.concat([id]);
        root.removedIds = merged;
        root.notifications = root.notifications.filter(n => n.id !== id);
        root.persistRemoved(merged);
    }

    function invoke(id) {
        Quickshell.execDetached(["makoctl", "invoke", "-n", String(id)]);
    }

    // mako não tem comando pra "limpar/remover histórico", então guardamos
    // os ids removidos localmente e filtramos a lista a partir daí.
    Process {
        id: removedReader
        command: ["cat", "/tmp/qs-music-popup-notif-cleared"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                root.removedIds = raw === "" ? [] : raw.split(",").map(s => parseInt(s)).filter(n => !isNaN(n));
                root.refresh();
            }
        }
    }

    Process {
        id: historyProc
        command: ["makoctl", "history", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const allIds = data.map(n => n.id);
                    // poda ids removidos que já saíram do histórico do mako
                    // (evita que o arquivo cresça pra sempre)
                    const pruned = root.removedIds.filter(id => allIds.includes(id));
                    if (pruned.length !== root.removedIds.length) {
                        root.removedIds = pruned;
                        root.persistRemoved(pruned);
                    }
                    root.notifications = data
                        .filter(n => !root.removedIds.includes(n.id))
                        .sort((a, b) => b.id - a.id);
                } catch (e) {
                    root.notifications = [];
                }
            }
        }
    }

    Component.onCompleted: removedReader.running = true

    Timer {
        interval: 3000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }
    onVisibleChanged: if (visible) refresh()

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Item {
            id: headerRow
            width: parent.width
            height: 20

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notificações (" + root.notifications.length + ")"
                color: root.cText
                font.pixelSize: 13
                font.bold: true
                font.family: root.textFont
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.notifications.length > 0
                text: "Limpar"
                color: root.cAccent
                font.pixelSize: 12
                font.family: root.textFont

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearAll()
                }
            }
        }

        Text {
            visible: root.notifications.length === 0
            width: parent.width
            text: "Nenhuma notificação recente"
            color: root.cDim
            font.pixelSize: 13
            font.family: root.textFont
            horizontalAlignment: Text.AlignHCenter
            topPadding: 60
        }

        ListView {
            visible: root.notifications.length > 0
            width: parent.width
            height: col.height - headerRow.height - col.spacing
            clip: true
            spacing: 6
            model: root.notifications

            delegate: Rectangle {
                width: ListView.view.width
                height: cardCol.implicitHeight + 16
                radius: 8
                color: root.cRow

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.invoke(modelData.id)
                }

                Column {
                    id: cardCol
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: modelData.app_name || "Notificação"
                        color: root.cAccent
                        font.pixelSize: 11
                        font.bold: true
                        font.family: root.textFont
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.summary || ""
                        color: root.cText
                        font.pixelSize: 12
                        font.family: root.textFont
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        visible: (modelData.body || "") !== ""
                        text: modelData.body || ""
                        color: root.cDim
                        font.pixelSize: 11
                        font.family: root.textFont
                        wrapMode: Text.Wrap
                    }
                }

                Item {
                    id: closeHit
                    width: 22
                    height: 22
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 4

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 12
                        font.family: root.textFont
                        color: closeMouse.containsMouse ? root.cText : root.cDim
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeOne(modelData.id)
                    }
                }
            }
        }
    }
}
