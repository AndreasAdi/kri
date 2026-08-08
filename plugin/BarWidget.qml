import QtQuick
import qs.Ui
import qs.Commons
import "Songs.js" as Songs

// Now-playing pill. Reads the same Service singleton the overlay uses, so it is
// a pure view — no playback state of its own.
BarWidget {
  id: root
  moduleName: "andreas.kri"

  readonly property var service: bar?.shell?.serviceFor("andreas.kri")
  readonly property var song: service ? service.currentSong : null
  readonly property bool hasTrack: song !== null && song !== undefined
  readonly property bool playing: service ? service.playing : false

  // Stanza counter is the one thing worth surfacing on the bar that MPRIS
  // widgets cannot show: it tells you where you are in the hymn at a glance.
  readonly property string stanzaLabel: service && service.hasCues && service.currentPart > 0
    ? " · bait " + service.currentPart : ""

  property real maxLabelWidth: setting("maxLabelWidth", Style.space(190))

  visible: hasTrack
  implicitWidth: hasTrack ? content.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyph
      anchors.verticalCenter: parent.verticalCenter
      text: root.playing ? "󰎇" : "󰎊"
      color: root.playing ? root.bar.barForeground : Qt.darker(root.bar.barForeground, 1.5)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body

      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    Item {
      id: clip
      width: Math.min(root.maxLabelWidth, label.implicitWidth)
      height: glyph.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical && root.hasTrack

      Text {
        id: label
        text: root.hasTrack ? root.song.no + " " + root.song.title : ""
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter

        readonly property bool needsScroll: implicitWidth > clip.width

        NumberAnimation on x {
          running: label.needsScroll && !root.bar.vertical
          loops: Animation.Infinite
          duration: Math.max(6000, label.implicitWidth * 25)
          from: clip.width
          to: -label.implicitWidth
          easing.type: Easing.Linear
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function (mouse) {
      if (mouse.button === Qt.RightButton) {
        if (root.service) root.service.togglePlayback()
      } else if (mouse.button === Qt.MiddleButton) {
        if (root.service) root.service.stop()
      } else if (root.bar && root.bar.shell) {
        root.bar.shell.toggle("andreas.kri", "{}")
      }
    }

    onWheel: function (wheel) {
      if (!root.service) return
      if (wheel.angleDelta.y > 0) root.service.previous()
      else if (wheel.angleDelta.y < 0) root.service.next()
    }

    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasTrack
      ? "KRI " + root.song.no + " · " + root.song.title + root.stanzaLabel
        + "  (" + Songs.formatTime(root.service.position) + " / " + Songs.formatTime(root.service.duration) + ")"
      : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
