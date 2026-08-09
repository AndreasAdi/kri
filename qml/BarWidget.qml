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

  // Long titles are elided rather than scrolled: 36% of the 335 hymn labels
  // overflow, and most by only two or three characters — a marquee would be in
  // near-constant motion to reveal almost nothing. The full title lives in the
  // tooltip instead. Same trade omarchy.active-window makes.
  //   omarchy bar set andreas.kri titleDisplay number
  //   omarchy bar set andreas.kri maxLabelWidth 140
  readonly property string titleDisplay: String(setting("titleDisplay", "elide"))
  // Applies to the title alone. 240px fits ~33 characters, which shows 324 of
  // the 335 hymn titles (97%) in full; the rest elide.
  readonly property real maxLabelWidth: Number(setting("maxLabelWidth", Style.space(240)))
  // A vertical bar has no room for a title, so it is number-only regardless.
  readonly property bool showTitle: titleDisplay !== "number" && bar && !bar.vertical

  visible: hasTrack
  implicitWidth: hasTrack ? content.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  // Songs differ in title length, so the pill resizes on every change. Easing
  // that keeps the widgets beside it from snapping. Unlike the marquee this
  // fires once per song, not forever.
  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

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

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.service ? root.service.repeatSong : false
      text: "󰑖"
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    // Number and title are separate items, not one string: the number is the
    // identifier people actually use, so it must be structurally impossible for
    // elision to eat into it no matter how narrow maxLabelWidth gets.
    Text {
      id: numberLabel
      anchors.verticalCenter: parent.verticalCenter
      visible: root.hasTrack
      text: root.hasTrack ? root.song.no : ""
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      id: titleLabel
      anchors.verticalCenter: parent.verticalCenter
      // Only as wide as it needs to be, up to the cap — a short title must not
      // leave dead space in the bar.
      width: Math.min(root.maxLabelWidth, implicitWidth)
      visible: root.showTitle && root.hasTrack && text !== ""
      text: root.hasTrack ? root.song.title : ""
      elide: Text.ElideRight
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
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
        + (root.service.repeatSong ? "  · diulang" : "")
      : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
