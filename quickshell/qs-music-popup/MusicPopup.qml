import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Rectangle {
    id: root

    color: "transparent"
    border.width: 0
    radius: 10

    implicitWidth: 380
    implicitHeight: popupColumn.implicitHeight + 24

    // ── Theme (Catppuccin Mocha) ──
    readonly property color cBackground: "#1e1e2e"
    readonly property color cRow:        "#313244"
    readonly property color cTrack:      Qt.rgba(1, 1, 1, 0.12)
    readonly property color cText:       "#cdd6f4"
    readonly property color cDim:        "#a6adc8"
    readonly property color cAccent:     "#89b4fa"

    FontLoader {
        id: iconFontLoader
        source: "file:///usr/share/fonts/fontawesome-6-free-fonts/Font%20Awesome%206%20Free-Solid-900.otf"
    }
    FontLoader {
        id: brandFontLoader
        source: "file:///usr/share/fonts/fontawesome-6-brands-fonts/Font%20Awesome%206%20Brands-Regular-400.otf"
    }

    readonly property string textFont: "JetBrains Mono"
    readonly property string iconFont: iconFontLoader.name
    readonly property string brandFont: brandFontLoader.name

    // ── Helpers ──
    function getCleanMetadata(rawTitle, rawArtist) {
        let t = (rawTitle || "").replace(/\s*-\s*YouTube$/, "")
                                 .replace(/\s*-\s*Mozilla Firefox$/, "")
                                 .replace(/\s*-\s*Zen Browser$/, "")
                                 .trim();
        let a = (rawArtist || "").trim();
        if (a === "" && t.includes(" - ")) {
            const parts = t.split(" - ");
            a = parts[0].trim();
            t = parts.slice(1).join(" - ").trim();
        }
        return { title: t, artist: a };
    }

    function getPlayerIcon(identity) {
        const id = (identity || "").toLowerCase();
        if (id.includes("spotify")) return "S";
        if (id.includes("firefox")) return "F";
        if (id.includes("zen"))     return "Z";
        if (id.includes("chrome"))  return "C";
        if (id.includes("vlc"))     return "V";
        if (id.includes("mpv"))     return "M";
        return "♪";
    }

    function fmtTime(secs) {
        if (!secs || secs < 0) return "0:00";
        const s = Math.floor(secs);
        const m = Math.floor(s / 60);
        const h = Math.floor(m / 60);
        const rem = s % 60;
        if (h > 0) return h + ":" + (m % 60).toString().padStart(2, "0") + ":" + rem.toString().padStart(2, "0");
        return m + ":" + (rem < 10 ? "0" + rem : rem);
    }

    // ── Player list ──
    readonly property var playerList: {
        const result = [];
        const vals = Mpris.players.values;
        for (let i = 0; i < vals.length; i++) {
            const p = vals[i];
            if (p && (p.trackTitle ?? "") !== "") result.push(p);
        }
        return result;
    }

    property int selectedIndex: 0

    onPlayerListChanged: {
        if (playerList.length === 0) selectedIndex = 0;
        else if (selectedIndex >= playerList.length) selectedIndex = playerList.length - 1;
    }

    readonly property MprisPlayer activePlayer: {
        if (playerList.length === 0) return null;
        const sel = playerList[selectedIndex];
        if (sel) return sel;
        for (let i = 0; i < playerList.length; i++) {
            if (playerList[i].playbackState === MprisPlaybackState.Playing)
                return playerList[i];
        }
        return playerList[0];
    }

    onActivePlayerChanged: {
        const idx = playerList.indexOf(activePlayer);
        if (idx !== -1) selectedIndex = idx;
        userSeeking = false;
        _stableLength = activePlayer?.length ?? 0;
        livePosition = activePlayer?.position ?? 0;
        updateMetadata();
    }

    Connections {
        target: root.activePlayer
        function onTrackChanged() {
            root._stableLength = root.activePlayer?.length ?? 0;
            root.livePosition = 0;
            root.updateMetadata();
        }
        function onTrackTitleChanged()  { root.updateMetadata(); }
        function onTrackArtistChanged() { root.updateMetadata(); }
        function onLengthChanged() {
            const newLen = root.activePlayer?.length ?? 0;
            if (newLen <= 0) return;
            const pos = root.livePosition;
            if (Math.abs(newLen - pos) < 2) return;
            if (root._stableLength <= 0 || newLen >= root._stableLength)
                root._stableLength = newLen;
        }
    }

    readonly property bool isPlaying:   root.activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property bool hasContent:  root.activePlayer !== null
    readonly property bool multiPlayer: root.playerList.length > 1

    property real livePosition: 0
    property real _stableLength: 0
    property bool userSeeking: false

    Timer {
        interval: 1000
        repeat: true
        running: root.isPlaying && !root.userSeeking
        onTriggered: {
            if (root.activePlayer) {
                const pos = root.activePlayer.position;
                if (pos === 0 && root.livePosition > 1) return;
                root.livePosition = pos;
            }
        }
    }

    readonly property int _liveThreshold: 86400 * 365
    readonly property bool isLiveStream: (root._stableLength <= 0 || root._stableLength > root._liveThreshold)

    // ── Metadata text (single slot, no crossfade to keep it simple) ──
    property string _titleText:  "Unknown Title"
    property string _artistText: "Unknown Artist"
    property string _identityText: ""

    function updateMetadata() {
        const meta = getCleanMetadata(root.activePlayer?.trackTitle, root.activePlayer?.trackArtist);
        root._titleText  = meta.title  || "Unknown Title";
        root._artistText = meta.artist || "Unknown Artist";

        let id = root.activePlayer?.identity ?? "";
        const low = id.toLowerCase();
        if (low.includes("firefox"))       id = "Firefox";
        else if (low.includes("zen"))      id = "Zen";
        else if (low.includes("chrome"))   id = "Chrome";
        else if (low.includes("spotify"))  id = "Spotify";
        else if (low.includes("vlc"))      id = "VLC";
        else if (low.includes("mpv"))      id = "mpv";
        root._identityText = id;
    }

    // ── UI ──
    Column {
        id: popupColumn
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; margins: 12 }
        spacing: 12

        Text {
            visible: !root.hasContent
            width: parent.width
            text: "No active media session"
            font.pixelSize: 13
            font.family: root.textFont
            color: root.cDim
            horizontalAlignment: Text.AlignHCenter
            topPadding: 8
            bottomPadding: 8
        }

        Row {
            visible: root.hasContent
            width: parent.width
            spacing: 12

            Item {
                id: artContainer
                width: 72
                height: 72

                property string _urlA: ""
                property string _urlB: ""
                property bool   _showA: true

                function switchArt(newUrl) {
                    if (!newUrl || newUrl === _urlA || newUrl === _urlB) return;
                    if (_showA) {
                        _urlB = newUrl;
                        _showA = false;
                    } else {
                        _urlA = newUrl;
                        _showA = true;
                    }
                }

                Connections {
                    target: root
                    function onActivePlayerChanged() {
                        artContainer.switchArt(root.activePlayer?.trackArtUrl ?? "");
                    }
                }

                Connections {
                    target: root.activePlayer
                    function onTrackArtUrlChanged() {
                        artContainer.switchArt(root.activePlayer?.trackArtUrl ?? "");
                    }
                }

                Image {
                    id: artImageA
                    anchors.fill: parent
                    anchors.margins: 2
                    source: artContainer._urlA
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    mipmap: true
                    smooth: true
                    opacity: artContainer._showA ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutSine } }
                    visible: opacity > 0
                }

                Image {
                    id: artImageB
                    anchors.fill: parent
                    anchors.margins: 2
                    source: artContainer._urlB
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    mipmap: true
                    smooth: true
                    opacity: artContainer._showA ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutSine } }
                    visible: opacity > 0
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: root.cAccent
                    radius: 4
                }

                Text {
                    visible: artImageA.status !== Image.Ready && artImageB.status !== Image.Ready
                    anchors.centerIn: parent
                    text: "♪"
                    font.pixelSize: 28
                    font.family: root.textFont
                    color: root.cDim
                    z: 1
                }
            }

            Column {
                width: parent.width - artContainer.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Item {
                    width: parent.width
                    height: 22
                    clip: true
                    Text {
                        id: titleText
                        text: root._titleText
                        font.pixelSize: 15
                        font.bold: true
                        font.family: root.textFont
                        color: root.cAccent
                        readonly property bool overflow: implicitWidth > parent.width
                        onOverflowChanged: { marquee.stop(); titleText.x = 0; if (overflow) marquee.start() }
                        onTextChanged:     { marquee.stop(); titleText.x = 0; if (overflow) marquee.start() }
                        SequentialAnimation {
                            id: marquee
                            running: false; loops: Animation.Infinite
                            PauseAnimation { duration: 1200 }
                            NumberAnimation { target: titleText; property: "x"; from: 0; to: -titleText.implicitWidth; duration: titleText.implicitWidth * 14; easing.type: Easing.Linear }
                            PropertyAction  { target: titleText; property: "x"; value: titleText.parent.width }
                            NumberAnimation { target: titleText; property: "x"; from: titleText.parent.width; to: 0; duration: titleText.implicitWidth * 10; easing.type: Easing.Linear }
                            PauseAnimation { duration: 1200 }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root._artistText
                    font.pixelSize: 12
                    font.family: root.textFont
                    color: root.cDim
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: root._identityText !== ""
                    height: 18
                    width: pillRow.implicitWidth + 12
                    radius: height / 2
                    color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.15)
                    Row {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: root.getPlayerIcon(root._identityText)
                            font.pixelSize: 10
                            font.family: root.textFont
                            color: root.cAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root._identityText
                            font.pixelSize: 9
                            font.bold: true
                            font.family: root.textFont
                            color: root.cAccent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        Column {
            visible: root.hasContent && (root.activePlayer?.positionSupported ?? false)
            width: parent.width
            spacing: 4

            WaveBar {
                id: waveBar
                width: parent.width
                accentColor: root.cAccent
                from: 0
                to: root.isLiveStream ? 1 : Math.max(1, root._stableLength)
                value: root.isLiveStream ? 1.0 : Math.min(root.livePosition, Math.max(1, root._stableLength))
                playing: root.isPlaying
                forceNoNeedle: root.isLiveStream
                seekable: !root.isLiveStream && (root.activePlayer?.canSeek ?? false)
                onSeeked: (v) => {
                    root.userSeeking = true;
                    const targetPos = Math.max(0, Math.min(v, root._stableLength));
                    root.activePlayer.position = targetPos;
                    root.livePosition = targetPos;
                    seekReleaseTimer.restart();
                }
            }

            Timer {
                id: seekReleaseTimer
                interval: 1200
                onTriggered: root.userSeeking = false
            }

            Row {
                width: parent.width
                Text {
                    id: posLeft
                    text: root.isLiveStream ? "Live" : root.fmtTime(root.livePosition)
                    font.pixelSize: 11
                    font.family: root.textFont
                    color: root.cDim
                }
                Item { width: parent.width - posLeft.implicitWidth - posRight.implicitWidth; height: 1 }
                Text {
                    id: posRight
                    text: root.isLiveStream ? "∞" : root.fmtTime(root._stableLength)
                    font.pixelSize: 11
                    font.family: root.textFont
                    color: root.cDim
                }
            }
        }

        Item {
            visible: root.hasContent
            width: parent.width
            height: playPauseBtn.height

            MediaButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                opacity: (root.activePlayer?.shuffleSupported ?? false) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutSine } }
                visible: opacity > 0
                icon: "⇄"
                accentColor: root.cAccent
                highlighted: root.activePlayer?.shuffle ?? false
                onClicked: {
                    if (root.activePlayer)
                        root.activePlayer.shuffle = !(root.activePlayer.shuffle ?? false);
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                MediaButton {
                    icon: "⏮"; accentColor: root.cAccent
                    enabled: root.activePlayer?.canGoPrevious ?? false
                    opacity: enabled ? 1.0 : 0.45
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutSine } }
                    onClicked: root.activePlayer?.previous()
                }
                MediaButton {
                    id: playPauseBtn
                    icon: root.isPlaying ? "⏸" : "▶"
                    highlighted: true
                    accentColor: root.cAccent
                    enabled: root.isPlaying ? (root.activePlayer?.canPause ?? false) : (root.activePlayer?.canPlay ?? false)
                    onClicked: root.isPlaying ? root.activePlayer?.pause() : root.activePlayer?.play()
                }
                MediaButton {
                    icon: "⏭"; accentColor: root.cAccent
                    enabled: root.activePlayer?.canGoNext ?? false
                    opacity: enabled ? 1.0 : 0.45
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutSine } }
                    onClicked: root.activePlayer?.next()
                }
            }

            MediaButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                opacity: (root.activePlayer?.loopSupported ?? false) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutSine } }
                visible: opacity > 0
                icon: (root.activePlayer?.loopState ?? MprisLoopState.None) === MprisLoopState.Track ? "↻¹" : "↻"
                accentColor: root.cAccent
                highlighted: (root.activePlayer?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: {
                    if (!root.activePlayer) return;
                    const s = root.activePlayer.loopState ?? MprisLoopState.None;
                    if (s === MprisLoopState.None)           root.activePlayer.loopState = MprisLoopState.Playlist;
                    else if (s === MprisLoopState.Playlist)  root.activePlayer.loopState = MprisLoopState.Track;
                    else                                     root.activePlayer.loopState = MprisLoopState.None;
                }
            }
        }
    }

    // ── Components ──
    component PlayerNavButton: Rectangle {
        id: navBtn
        property string icon: ""
        property color accentColor: root.cAccent
        signal clicked()
        width: 36; height: 36; radius: 10
        color: navMouse.containsMouse ? Qt.lighter(root.cRow, 1.3) : root.cRow
        border.color: "#181825"
        border.width: 2
        scale: navMouse.pressed ? 0.88 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Text {
            anchors.centerIn: parent
            text: navBtn.icon
            font.pixelSize: 16
            font.family: root.textFont
            color: navMouse.containsMouse ? navBtn.accentColor : root.cText
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: navMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navBtn.clicked()
        }
    }

    component WaveBar: Item {
        id: bar
        property real value: 0
        property real from: 0
        property real to: 100
        property color accentColor: root.cAccent
        property bool playing: false
        property bool seekable: true
        property bool forceNoNeedle: false
        signal seeked(real value)
        implicitWidth: 120
        implicitHeight: 28
        property bool dragging: barMouse.pressed
        property real internalValue: 0
        readonly property bool activeInteraction: dragging
        readonly property bool isNeedle: !forceNoNeedle && (activeInteraction || playing)
        readonly property bool hovered: barMouse.containsMouse || barMouse.pressed
        readonly property real targetValue: activeInteraction ? internalValue : value
        property real animValue: targetValue
        Behavior on animValue {
            enabled: !bar.dragging
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
        readonly property real _fillWidth: ((bar.animValue - bar.from) / (bar.to - bar.from)) * bar.width
        function _updateFromMouse(mouseX) {
            var newVal = Math.max(bar.from, Math.min(bar.to, bar.from + (mouseX / bar.width) * (bar.to - bar.from)));
            bar.internalValue = newVal;
            bar.seeked(newVal);
        }
        property real _phase: 0
        NumberAnimation on _phase { from: 0; to: Math.PI * 2; duration: 1200; loops: Animation.Infinite; running: bar.playing && !bar.activeInteraction }
        property real _waveAmount: 0.0
        Behavior on _waveAmount { NumberAnimation { duration: 400; easing.type: Easing.InOutSine } }
        onPlayingChanged: _waveAmount = (playing && !activeInteraction) ? 1.0 : 0.0
        onActiveInteractionChanged: _waveAmount = (playing && !activeInteraction) ? 1.0 : 0.0

        property color _strokeColor: hovered ? Qt.lighter(bar.accentColor, 1.15) : bar.accentColor
        Behavior on _strokeColor { ColorAnimation { duration: 150 } }

        Rectangle {
            x: Math.max(0, bar._fillWidth - 3)
            width: Math.max(0, parent.width - x - 3); height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: bar.hovered ? Qt.rgba(root.cTrack.r, root.cTrack.g, root.cTrack.b, 0.4) : Qt.lighter(root.cTrack, 1.1)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Canvas {
            id: waveCanvas
            anchors.fill: parent; antialiasing: true
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (bar._fillWidth <= 0) return;
                const cy = height / 2; const amp = 3.5 * bar._waveAmount; const freq = 0.16;
                ctx.beginPath(); ctx.lineWidth = 6; ctx.lineCap = "round";
                ctx.strokeStyle = bar._strokeColor;
                const startX = 3;
                const endX = Math.min(bar._fillWidth, width - 3);
                if (bar._waveAmount > 0) {
                    for (let x = startX; x <= endX; x++) {
                        const y = cy + Math.sin(x * freq + bar._phase) * amp;
                        if (x === startX) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                } else { ctx.moveTo(startX, cy); ctx.lineTo(endX, cy); }
                ctx.stroke();
            }
            Connections {
                target: bar
                function onAnimValueChanged()    { waveCanvas.requestPaint() }
                function on_PhaseChanged()       { waveCanvas.requestPaint() }
                function on_WaveAmountChanged()  { waveCanvas.requestPaint() }
                function onHoveredChanged()      { waveCanvas.requestPaint() }
                function on_StrokeColorChanged() { waveCanvas.requestPaint() }
            }
        }
        Item {
            width: 0; height: 0; anchors.verticalCenter: parent.verticalCenter; x: bar._fillWidth
            opacity: bar.forceNoNeedle ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutSine } }
            Rectangle {
                anchors.centerIn: parent
                width: bar.isNeedle ? 6 : (bar.hovered ? 18 : 14)
                height: bar.isNeedle ? 24 : (bar.hovered ? 18 : 14)
                radius: width / 2
                color: bar.hovered ? Qt.lighter(bar.accentColor, 1.15) : bar.accentColor
                Behavior on width  { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on color  { ColorAnimation { duration: 150 } }
            }
        }
        MouseArea {
            id: barMouse; anchors.fill: parent; hoverEnabled: true; enabled: bar.seekable
            property bool _hasDragged: false
            onPressed: (mouse) => { bar.internalValue = bar.animValue; _hasDragged = false; }
            onPositionChanged: (mouse) => { if (pressed) { _hasDragged = true; bar._updateFromMouse(mouse.x); } }
            onClicked: (mouse) => { if (!_hasDragged) bar._updateFromMouse(mouse.x); }
        }
    }

    component MediaButton: Rectangle {
        id: btn
        property string icon: ""
        property bool highlighted: false
        property color accentColor: root.cAccent
        property bool enabled: true
        signal clicked()
        width: 40; height: 40; radius: 8
        color: {
            if (!enabled) return Qt.rgba(root.cRow.r, root.cRow.g, root.cRow.b, 0.35);
            if (highlighted) return btnMouse.containsMouse ? Qt.lighter(accentColor, 1.1) : accentColor;
            return btnMouse.containsMouse ? Qt.lighter(root.cRow, 1.25) : root.cRow;
        }
        border.color: highlighted ? "transparent" : Qt.rgba(1, 1, 1, btnMouse.containsMouse ? 0.10 : 0.04)
        border.width: 1
        scale: btnMouse.pressed ? 0.91 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Text {
            anchors.centerIn: parent; text: btn.icon
            font.pixelSize: 18; font.family: root.textFont
            color: {
                if (!btn.enabled)    return root.cDim;
                if (btn.highlighted) return "#1e1e2e";
                return btnMouse.containsMouse ? root.cAccent : root.cText;
            }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: btnMouse; anchors.fill: parent; hoverEnabled: true; enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked()
        }
    }
}
