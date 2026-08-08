import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Songs.js" as Songs

// The overlay: search on the left, lyrics on the right, playback along the
// bottom. Keyboard-first — it follows the emoji picker's key-catcher pattern
// rather than a focused TextField so every shortcut stays reachable while typing.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  // Injected by the shell: the Service.qml singleton for this plugin.
  property var service: null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  // Follow the audio: highlighted stanza scrolls itself into view.
  property bool followAudio: true

  readonly property var songs: service ? service.songs : []
  property var results: []
  readonly property var previewSong: selectedIndex >= 0 && selectedIndex < results.length ? results[selectedIndex] : null
  // Karaoke highlighting only makes sense while you are looking at the hymn
  // that is actually playing.
  readonly property bool previewIsPlaying: previewSong && service && service.currentSong
    && previewSong.no === service.currentSong.no

  // Share the [menu] theme tokens, like the emoji and menu surfaces do.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily

  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Math.min(Style.space(1040), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(680), panel.height - Style.gapsOut * 2)
  property int sidebarWidth: Math.min(Style.space(330), Math.round(cardWidth * 0.34))
  property int rowHeight: Math.max(Style.space(38), Style.font.subtitle * 2.6)

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.followAudio = true
    root.rebuild()
    // Land on the playing hymn when there is one, so reopening resumes context.
    if (service && service.currentSong) root.selectNumber(service.currentSong.no)
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "andreas.kri")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function rebuild() {
    root.results = Songs.search(root.songs, root.filterText, 400)
    if (root.selectedIndex >= root.results.length) root.selectedIndex = Math.max(0, root.results.length - 1)
    if (root.selectedIndex < 0) root.selectedIndex = 0
    Qt.callLater(function () {
      if (root.results.length > 0) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function setFilter(next) {
    root.filterText = next
    root.selectedIndex = 0
    root.rebuild()
  }

  function selectNumber(number) {
    for (var i = 0; i < root.results.length; i++) {
      if (root.results[i].no === number) {
        root.selectedIndex = i
        resultList.positionViewAtIndex(i, ListView.Contain)
        return
      }
    }
  }

  function moveSelection(delta) {
    if (root.results.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.results.length) % root.results.length
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    lyricList.positionViewAtBeginning()
  }

  function playSelected() {
    if (!service || !root.previewSong) return
    service.playNumber(root.previewSong.no)
    root.followAudio = true
  }

  function stepStanza(delta) {
    if (!service || !root.previewIsPlaying || !service.hasCues) return
    var target = Math.max(1, service.currentPart + delta)
    service.seekToPart(target)
  }

  onSongsChanged: rebuild()

  // Autoscroll the lyrics so the stanza being sung stays on screen.
  Connections {
    target: root.service
    enabled: root.service !== null
    function onCurrentPartChanged() {
      if (!root.opened || !root.followAudio || !root.previewIsPlaying) return
      var part = root.service.currentPart
      if (part > 0) lyricList.positionViewAtIndex(part - 1, ListView.Contain)
    }
    function onSongActivated(index) {
      if (!root.opened) return
      var song = root.service.songs[index]
      if (song) root.selectNumber(song.no)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "kri"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function (event) {
          var ctrl = (event.modifiers & Qt.ControlModifier) !== 0

          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
          } else if (event.key === Qt.Key_Up) {
            root.moveSelection(-1)
          } else if (event.key === Qt.Key_Down) {
            root.moveSelection(1)
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.playSelected()
          } else if (ctrl && event.key === Qt.Key_Space) {
            if (root.service) root.service.togglePlayback()
          } else if (ctrl && event.key === Qt.Key_N) {
            if (root.service) root.service.next()
          } else if (ctrl && event.key === Qt.Key_P) {
            if (root.service) root.service.previous()
          } else if (ctrl && event.key === Qt.Key_K) {
            root.followAudio = !root.followAudio
          } else if (ctrl && event.key === Qt.Key_Right) {
            root.stepStanza(1)
          } else if (ctrl && event.key === Qt.Key_Left) {
            root.stepStanza(-1)
          } else if (event.key === Qt.Key_PageDown) {
            lyricList.flick(0, -1200)
          } else if (event.key === Qt.Key_PageUp) {
            lyricList.flick(0, 1200)
          } else if (event.text && event.text.length === 1
                     && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
          } else {
            return
          }
          event.accepted = true
        }
      }

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        // ------------------------------------------------------- left: search
        Item {
          id: sidebar
          width: root.sidebarWidth
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left

          Text {
            id: searchLine
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(Style.space(34), Style.font.heading + Style.spacing.controlPaddingY * 2)
            verticalAlignment: Text.AlignVCenter
            text: root.filterText || "Cari nomor, judul, atau lirik…"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: resultCount
            anchors.top: searchLine.bottom
            anchors.left: parent.left
            text: root.songs.length === 0
              ? "Belum ada data — jalankan 'kri sync'"
              : root.results.length + " dari " + root.songs.length + " kidung"
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          ListView {
            id: resultList
            anchors.top: resultCount.bottom
            anchors.topMargin: Style.spacing.md
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.panelGap
            anchors.bottom: parent.bottom
            clip: true
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            spacing: Style.space(1)

            delegate: Rectangle {
              id: row
              required property int index
              required property var modelData

              readonly property bool active: index === root.selectedIndex
              readonly property bool isPlaying: root.service && root.service.currentSong
                && root.service.currentSong.no === modelData.no

              width: resultList.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: active ? root.selectedBackground : "transparent"

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.spacing.lg
                anchors.rightMargin: Style.spacing.lg
                spacing: Style.spacing.lg

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(30)
                  text: row.modelData.no
                  color: row.active ? root.selectedText : root.foreground
                  opacity: row.active ? 0.9 : 0.55
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(30) - Style.spacing.lg * 2 - Style.space(16)
                  spacing: Style.space(1)

                  Text {
                    text: row.modelData.title
                    color: row.active ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: row.modelData.hymnTune
                    color: row.active ? root.selectedText : root.foreground
                    opacity: 0.5
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text !== ""
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(16)
                  text: row.isPlaying ? "󰝚" : (row.modelData.media ? "" : "󰝛")
                  color: row.active ? root.selectedText : root.foreground
                  opacity: row.isPlaying ? 0.95 : 0.3
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  horizontalAlignment: Text.AlignRight
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.selectedIndex = row.index
                onClicked: {
                  root.selectedIndex = row.index
                  root.playSelected()
                }
              }
            }
          }
        }

        Rectangle {
          id: divider
          width: Math.max(1, Style.space(1))
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: sidebar.right
          color: root.foreground
          opacity: 0.12
        }

        // ------------------------------------------------------ right: lyrics
        Item {
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: divider.right
          anchors.leftMargin: Style.spacing.panelGap
          anchors.right: parent.right

          Column {
            id: songHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.space(2)
            visible: root.previewSong !== null

            Text {
              text: root.previewSong ? "KRI " + root.previewSong.no + " · " + root.previewSong.title : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: {
                if (!root.previewSong) return ""
                var bits = []
                if (root.previewSong.keyTime) bits.push(root.previewSong.keyTime)
                if (root.previewSong.hymnTune) bits.push(root.previewSong.hymnTune)
                if (root.previewSong.lyric) bits.push("Lirik: " + root.previewSong.lyric)
                if (root.previewSong.music) bits.push("Musik: " + root.previewSong.music)
                return bits.join("  ·  ")
              }
              color: root.foreground
              opacity: 0.55
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          ListView {
            id: lyricList
            anchors.top: songHeader.bottom
            anchors.topMargin: Style.spacing.panelGap
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: playerBar.top
            anchors.bottomMargin: Style.spacing.panelGap
            clip: true
            model: root.previewSong ? root.previewSong.parts : []
            boundsBehavior: Flickable.StopAtBounds
            spacing: Style.spacing.md

            delegate: Rectangle {
              id: stanza
              required property int index
              required property var modelData

              readonly property bool active: root.previewIsPlaying && root.service
                && root.service.currentPart === index + 1

              width: lyricList.width
              implicitHeight: stanzaLines.implicitHeight + Style.spacing.lg * 2
              radius: root.cornerRadius
              color: active ? root.selectedBackground : "transparent"

              Behavior on color { ColorAnimation { duration: 220 } }

              Text {
                id: stanzaNumber
                anchors.top: parent.top
                anchors.topMargin: Style.spacing.lg
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.lg
                width: Style.space(22)
                text: stanza.index + 1
                color: stanza.active ? root.selectedText : root.foreground
                opacity: stanza.active ? 0.85 : 0.35
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Column {
                id: stanzaLines
                anchors.top: parent.top
                anchors.topMargin: Style.spacing.lg
                anchors.left: stanzaNumber.right
                anchors.leftMargin: Style.spacing.md
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.lg
                spacing: Style.space(2)

                Repeater {
                  model: stanza.modelData

                  Text {
                    required property var modelData
                    text: modelData
                    color: stanza.active ? root.selectedText : root.foreground
                    opacity: stanza.active ? 1.0 : 0.75
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    wrapMode: Text.WordWrap
                    width: stanzaLines.width
                    visible: text !== ""
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: root.previewIsPlaying && root.service && root.service.hasCues
                  ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (root.previewIsPlaying && root.service) root.service.seekToPart(stanza.index + 1)
                  else root.playSelected()
                }
              }
            }
          }

          // ------------------------------------------------ playback + hints
          Column {
            id: playerBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.spacing.md

            Rectangle {
              width: parent.width
              height: Math.max(2, Style.space(3))
              radius: height / 2
              color: root.foreground
              opacity: 0.15
              visible: root.service && root.service.hasTrack

              Rectangle {
                height: parent.height
                radius: parent.radius
                color: root.foreground
                width: root.service && root.service.duration > 0
                  ? parent.width * (root.service.position / root.service.duration) : 0
              }

              MouseArea {
                anchors.fill: parent
                anchors.margins: -Style.space(6)
                cursorShape: Qt.PointingHandCursor
                onClicked: function (mouse) {
                  if (!root.service || root.service.duration <= 0) return
                  root.service.seekSeconds((mouse.x / width) * (root.service.duration / 1000))
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.spacing.lg

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  if (!root.service) return ""
                  if (root.service.lastError) return root.service.lastError
                  if (!root.service.hasTrack) return "Enter untuk memutar"
                  // A status readout, not a button: show the state we are in.
                  return (root.service.playing ? "󰐊" : "󰏤") + "  KRI " + root.service.currentSong.no
                    + "  " + Songs.formatTime(root.service.position)
                    + " / " + Songs.formatTime(root.service.duration)
                }
                color: root.foreground
                opacity: root.service && root.service.lastError ? 0.9 : 0.7
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                width: Math.max(0, parent.width - followLabel.width - Style.spacing.lg)
              }

              Text {
                id: followLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.followAudio ? "󰓾 ikuti audio" : "󰓾 bebas"
                color: root.foreground
                opacity: root.followAudio ? 0.8 : 0.35
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.followAudio = !root.followAudio
                }
              }
            }

            Text {
              width: parent.width
              text: "↑↓ pilih · Enter putar · Ctrl+Space jeda · Ctrl+←/→ bait · Ctrl+N/P lagu · Ctrl+K ikuti · Esc tutup"
              color: root.foreground
              opacity: 0.35
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          // Empty state — covers both "no data yet" and "no search match".
          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: root.previewSong === null

            Text {
              text: "󰎇"
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Text {
              text: root.songs.length === 0
                ? "Jalankan 'kri sync' untuk mengunduh 333 kidung"
                : "Tidak ada kidung yang cocok"
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }
        }
      }
    }
  }
}
