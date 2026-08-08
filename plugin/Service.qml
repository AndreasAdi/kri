import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import "Songs.js" as Songs

// Headless singleton: owns the hymnal, the audio player, and the karaoke clock.
// The overlay and the bar widget are both views onto this one instance, which is
// why playback survives closing the overlay.
Item {
  id: root

  // Injected by omarchy-shell's service loader.
  property var shell: null
  property var manifest: null

  readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/kri"

  property var songs: []
  readonly property bool loaded: songs.length > 0

  property int currentIndex: -1
  readonly property var currentSong: currentIndex >= 0 && currentIndex < songs.length ? songs[currentIndex] : null

  readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
  readonly property bool hasTrack: currentSong !== null
  readonly property int position: player.position
  readonly property int duration: player.duration

  // The whole point of the karaoke mode: which stanza the audio is inside right
  // now. 0 means "before the first cue" or "this hymn has no cues".
  readonly property int currentPart: currentSong ? Songs.partAt(currentSong.cues, player.position / 1000) : 0
  readonly property bool hasCues: currentSong && currentSong.cues && currentSong.cues.length > 0

  // Streaming a hymn also queues it for the offline cache, so the library fills
  // itself as you use it rather than demanding a 1.6 GB download up front.
  property bool cacheOnPlay: true

  property string lastError: ""

  // `kri install` puts the CLI in ~/.local/bin, but a login shell spawned from
  // the compositor does not necessarily have that on PATH — so put it there.
  readonly property string kriBin: "PATH=\"$HOME/.local/bin:$PATH\"; kri"

  signal songActivated(int index)

  function reload() {
    songsFile.reload()
  }

  function playIndex(index) {
    if (index < 0 || index >= songs.length) return
    root.currentIndex = index
    root.lastError = ""
    resolver.resolve(songs[index].no)
    root.songActivated(index)
  }

  function playNumber(number) {
    var index = Songs.indexOfNumber(songs, number)
    if (index >= 0) playIndex(index)
    else root.lastError = "No hymn numbered " + number
  }

  // Select without starting playback — used when browsing the overlay.
  function showNumber(number) {
    var index = Songs.indexOfNumber(songs, number)
    if (index >= 0) root.currentIndex = index
  }

  function togglePlayback() {
    if (!hasTrack) return
    if (playing) player.pause()
    else player.play()
  }

  function stop() {
    player.stop()
  }

  function next() {
    if (songs.length === 0) return
    playIndex(currentIndex < 0 ? 0 : (currentIndex + 1) % songs.length)
  }

  function previous() {
    if (songs.length === 0) return
    playIndex(currentIndex <= 0 ? songs.length - 1 : currentIndex - 1)
  }

  function seekSeconds(seconds) {
    if (player.seekable) player.position = Math.max(0, seconds * 1000)
  }

  function seekToPart(part) {
    if (!currentSong) return
    var at = Songs.timeOfPart(currentSong.cues, part)
    if (at >= 0) seekSeconds(at)
  }

  function statusLine() {
    if (!hasTrack) return "idle"
    return (playing ? "playing" : "paused") + " KRI " + currentSong.no + " " + currentSong.title
      + " [" + Songs.formatTime(player.position) + "/" + Songs.formatTime(player.duration) + "]"
      + (hasCues ? " bait " + currentPart : "")
  }

  FileView {
    id: songsFile
    path: root.dataDir + "/songs.json"
    watchChanges: true
    onLoaded: root.songs = Songs.parse(text())
    onFileChanged: reload()
    onLoadFailed: root.lastError = "Hymnal not cached yet — run 'kri sync'"
  }

  // `kri path` decides between the cached file and the upstream URL; keeping
  // that logic in one place means the plugin never has to stat the cache.
  Process {
    id: resolver
    property string pendingNumber: ""

    function resolve(number) {
      if (running) running = false
      pendingNumber = number
      command = ["bash", "-lc", root.kriBin + " path " + number]
      running = true
    }

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var source = String(text || "").trim()
        if (!source) {
          root.lastError = "Tidak ada audio untuk KRI " + resolver.pendingNumber
          return
        }
        root.lastError = ""
        player.source = source.indexOf("http") === 0 ? source : "file://" + source
        player.play()

        if (root.cacheOnPlay && source.indexOf("http") === 0)
          Quickshell.execDetached(["bash", "-lc", root.kriBin + " download " + resolver.pendingNumber])
      }
    }
  }

  MediaPlayer {
    id: player
    audioOutput: AudioOutput { id: output }
    onErrorOccurred: function(error, errorString) {
      root.lastError = errorString
    }
  }

  IpcHandler {
    target: "kri"

    // Resolution is async (it shells out to `kri path`), so this reports what it
    // asked for rather than a playback state that has not settled yet.
    function play(number: string): string {
      root.playNumber(number)
      if (root.lastError) return root.lastError
      return root.currentSong
        ? "KRI " + root.currentSong.no + " " + root.currentSong.title
        : "unknown hymn " + number
    }

    function seek(seconds: string): string {
      root.seekSeconds(Number(seconds))
      return root.statusLine()
    }

    function toggle(): string {
      root.togglePlayback()
      return root.statusLine()
    }

    function next(): string {
      root.next()
      return root.statusLine()
    }

    function prev(): string {
      root.previous()
      return root.statusLine()
    }

    function stop(): string {
      root.stop()
      return "stopped"
    }

    function status(): string {
      return root.statusLine()
    }

    // Diagnostics: last playback/resolution error, and whether the hymnal loaded.
    function diag(): string {
      return "songs=" + root.songs.length
        + " source=" + player.source
        + " state=" + player.playbackState
        + " status=" + player.mediaStatus
        + " error=" + (root.lastError || "none")
    }

    function reload(): string {
      root.reload()
      return "reloading"
    }
  }
}
