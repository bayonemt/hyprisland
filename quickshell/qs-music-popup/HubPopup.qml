import QtQuick

Rectangle {
    id: root

    color: "#1e1e2e"
    border.color: "#181825"
    border.width: 2
    radius: 10

    property int activeTab: 0 // 0 = Música, 1 = Notificações, 2 = Quick Settings

    readonly property var tabs: [
        { label: "Música", icon: "♪" },
        { label: "Notif.", icon: "🔔" },
        { label: "Ajustes", icon: "⚙" }
    ]

    // Altura fixa calibrada (medida via debug: o conteúdo real da aba de
    // Música precisa de 207px + 41px da tab bar = 248px; 270 dá uma folga
    // pequena). O Quickshell/Hyprland aqui não redimensiona a janela ao
    // vivo de forma confiável, então tem que ser um valor fixo certo.
    implicitWidth: 380
    implicitHeight: 270

    Column {
        id: col
        anchors.fill: parent
        spacing: 0

        Row {
            id: tabBar
            width: parent.width
            height: 40

            Repeater {
                model: root.tabs
                delegate: Rectangle {
                    width: tabBar.width / root.tabs.length
                    height: tabBar.height
                    color: root.activeTab === index ? "#313244" : "transparent"
                    radius: 8
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: modelData.icon
                            font.pixelSize: 13
                            color: root.activeTab === index ? "#89b4fa" : "#a6adc8"
                        }
                        Text {
                            text: modelData.label
                            font.pixelSize: 12
                            font.bold: root.activeTab === index
                            font.family: "JetBrains Mono"
                            color: root.activeTab === index ? "#89b4fa" : "#a6adc8"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = index
                    }
                }
            }
        }

        Rectangle {
            id: divider
            width: parent.width
            height: 1
            color: "#181825"
        }

        Item {
            id: pages
            width: parent.width
            height: col.height - tabBar.height - divider.height
            clip: true

            MusicPopup {
                id: musicPage
                anchors.fill: parent
                visible: root.activeTab === 0
            }

            NotificationsPanel {
                id: notificationsPage
                anchors.fill: parent
                visible: root.activeTab === 1
            }

            QuickSettingsPanel {
                id: quickSettingsPage
                anchors.fill: parent
                visible: root.activeTab === 2
            }
        }
    }
}
