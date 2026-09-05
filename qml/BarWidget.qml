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
  readonly property string number: hasTrack ? String(song.no) : ""

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

  // A vertical bar is 28px wide: no room for a title, so the glyph and the
  // hymn number stack instead, and the title lives only in the tooltip.
  // "icon" drops the number too, for a bar that is already crowded.
  //   omarchy bar set andreas.kri verticalDisplay icon
  readonly property string verticalDisplay: String(setting("verticalDisplay", "number"))
  readonly property bool showTitle: !vertical && titleDisplay !== "number"
  readonly property bool showNumber: !vertical || verticalDisplay !== "icon"

  // Stacked, the number has only the bar's width to live in. Measure it rather
  // than assume: the bar font and its size are both user settings, and "044e"
  // is a character wider than the 001-333 the rest of the hymnal uses.
  readonly property real numberSlot: barSize - Style.space(6)
  readonly property int numberFontSize: !vertical || numberMetrics.width <= numberSlot
    ? Style.font.body
    : Math.max(Style.space(8), Math.floor(Style.font.body * numberSlot / Math.max(1, numberMetrics.width)))

  visible: hasTrack
  implicitWidth: !hasTrack ? 0 : (vertical ? barSize : content.implicitWidth + Style.space(14))
  implicitHeight: !hasTrack ? 0 : (vertical ? content.implicitHeight + Style.space(10) : barSize)

  TextMetrics {
    id: numberMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    text: root.number
  }

  // Songs differ in title length, so the pill resizes on every change. Easing
  // that keeps the widgets beside it from snapping. Unlike the marquee this
  // fires once per song, not forever. Vertically the same is true of the
  // repeat glyph coming and going.
  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Behavior on implicitHeight {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  // One positioner for both orientations — a vertical bar is the same widget
  // turned through a right angle, not a different one. Invisible children are
  // skipped by the positioner, so the horizontal column count can stay at the
  // maximum.
  Grid {
    id: content
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 4
    spacing: Style.space(root.vertical ? 2 : 6)
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    Text {
      id: glyph
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
      visible: root.showNumber && root.hasTrack
      text: root.number
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: root.numberFontSize
    }

    Text {
      id: titleLabel
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

    // On a vertical bar the tooltip is the only place the title appears at all,
    // which is why it has always carried the whole line.
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasTrack
      ? "KRI " + root.song.no + " · " + root.song.title + root.stanzaLabel
        + "  (" + Songs.formatTime(root.service.position) + " / " + Songs.formatTime(root.service.duration) + ")"
        + (root.service.repeatSong ? "  · diulang" : "")
      : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
