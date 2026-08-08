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

  // Loop the current hymn — for learning a tune, or holding one hymn during a
  // service. It is a mode, not a per-track flag: switching hymns keeps looping.
  property bool repeatSong: false

  property string lastError: ""

  // `kri install` puts the CLI in ~/.local/bin, but a login shell spawned from
  // the compositor does not necessarily have that on PATH — so put it there.
  readonly property string kriBin: "PATH=\"$HOME/.local/bin:$PATH\"; kri"

  signal songActivated(int index)

  function reload() {
    songsFile.reload()
  }

  // 63 of the 335 hymns have no recording. Refusing here — before anything
  // moves — is what keeps the bar honest: it would otherwise name the new hymn
  // while the previous one is still audible. Nothing is lost by refusing, since
  // the overlay's lyric pane reads its own selection, not currentSong.
  function playIndex(index) {
    if (index < 0 || index >= songs.length) return
    var song = songs[index]
    if (!song.media) {
      root.lastError = "KRI " + song.no + " belum ada audionya"
      return
    }
    root.lastError = ""
    resolver.resolve(index)
  }

  function playNumber(number) {
    var index = Songs.indexOfNumber(songs, number)
    if (index >= 0) playIndex(index)
    else root.lastError = "No hymn numbered " + number
  }

  // Transport, not browsing: the overlay's own up/down keys walk the whole list.
  // Hymns without audio come in runs of up to nine, so stepping into one and
  // going quiet would make the control feel broken — and since playIndex now
  // refuses them without moving currentIndex, it would also get stuck there.
  function stepPlayable(delta) {
    if (songs.length === 0) return -1
    var from = currentIndex >= 0 ? currentIndex : (delta > 0 ? -1 : 0)
    for (var step = 1; step <= songs.length; step++) {
      var index = ((from + delta * step) % songs.length + songs.length) % songs.length
      if (songs[index].media) return index
    }
    return -1
  }

  function togglePlayback() {
    if (!hasTrack) return
    if (playing) player.pause()
    else player.play()
  }

  function stop() {
    player.stop()
  }

  function toggleRepeat() {
    root.repeatSong = !root.repeatSong
  }

  function next() {
    var index = stepPlayable(1)
    if (index >= 0) playIndex(index)
  }

  function previous() {
    var index = stepPlayable(-1)
    if (index >= 0) playIndex(index)
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
      + (repeatSong ? " repeat" : "")
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
    property int pendingIndex: -1

    function resolve(index) {
      if (running) running = false
      pendingIndex = index
      pendingNumber = root.songs[index].no
      command = ["bash", "-lc", root.kriBin + " path " + pendingNumber]
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
        // Aborting an in-flight resolve can still flush its output, so check
        // that what came back is what we last asked for. Both branches of
        // `kri path` name the hymn: the cache file is KRI-<no>.mp3 and the
        // upstream URL ends the same way.
        if (source.indexOf("KRI-" + resolver.pendingNumber + ".") === -1) return

        // The only place currentIndex moves, in the same block that replaces
        // the audio. That pairing is the whole sync guarantee: the bar can
        // never name one hymn while another is sounding.
        root.currentIndex = resolver.pendingIndex
        root.lastError = ""
        player.source = source.indexOf("http") === 0 ? source : "file://" + source
        player.play()
        root.songActivated(resolver.pendingIndex)

        if (root.cacheOnPlay && source.indexOf("http") === 0)
          Quickshell.execDetached(["bash", "-lc", root.kriBin + " download " + resolver.pendingNumber])
      }
    }
  }

  MediaPlayer {
    id: player
    audioOutput: AudioOutput { id: output }
    // Native looping: seamless, and position resets to 0 on each pass so the
    // karaoke highlight restarts at the first stanza on its own.
    loops: root.repeatSong ? MediaPlayer.Infinite : 1
    onErrorOccurred: function(error, errorString) {
      root.lastError = errorString
    }
  }

  IpcHandler {
    target: "kri"

    // Resolution is async (it shells out to `kri path`), so this reports the
    // hymn that was asked for — currentSong still names whatever is playing
    // right now. A hymn without audio is refused synchronously, so that case
    // does come back on this call.
    function play(number: string): string {
      var index = Songs.indexOfNumber(root.songs, number)
      if (index < 0) return "unknown hymn " + number
      root.playIndex(index)
      if (root.lastError) return root.lastError
      return "KRI " + root.songs[index].no + " " + root.songs[index].title
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

    function repeat(): string {
      root.toggleRepeat()
      return root.repeatSong ? "repeat on" : "repeat off"
    }

    // Separate from repeat() because IPC arguments are mandatory: a declared
    // parameter would make the bare toggle above impossible to call.
    // Explicit set keeps scripts idempotent without reading the state back.
    function repeatSet(mode: string): string {
      var wanted = String(mode || "").trim().toLowerCase()
      root.repeatSong = (wanted === "on" || wanted === "true" || wanted === "1")
      return root.repeatSong ? "repeat on" : "repeat off"
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
