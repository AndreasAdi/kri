.pragma library

// Query-side half of the search. The corpus side (the prebuilt `search` blob on
// every song) is produced by lib/sync.py — fold() here must match fold() there.
function fold(text) {
  return String(text || "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
}

function parse(rawJson) {
  if (!rawJson) return []
  try {
    var songs = JSON.parse(rawJson)
    return Array.isArray(songs) ? songs : []
  } catch (e) {
    console.warn("kri: songs.json is not valid JSON:", e)
    return []
  }
}

// Rank so the obvious intent wins: typing "24" should surface hymn 024 before
// every hymn whose lyrics happen to contain the word.
function score(song, tokens, rawQuery) {
  var numeric = /^[0-9]{1,3}[A-Za-z]?$/.test(rawQuery)
  if (numeric && song.no.toLowerCase() === canonicalNumber(rawQuery)) return 0
  if (song.titleFold === tokens.join(" ")) return 1
  if (song.titleFold.indexOf(tokens.join(" ")) === 0) return 2
  if (song.titleFold.indexOf(tokens.join(" ")) !== -1) return 3
  if (numeric && song.no.indexOf(rawQuery) !== -1) return 4
  return 5
}

function search(songs, query, limit) {
  var raw = String(query || "").trim()
  if (!raw) return songs.slice(0, limit || songs.length)

  var folded = fold(raw)
  var tokens = folded.split(" ").filter(function (t) { return t.length > 0 })
  if (tokens.length === 0) return songs.slice(0, limit || songs.length)

  var hits = []
  for (var i = 0; i < songs.length; i++) {
    var song = songs[i]
    var matched = true
    for (var t = 0; t < tokens.length; t++) {
      if (song.search.indexOf(tokens[t]) === -1) { matched = false; break }
    }
    if (matched) hits.push({ song: song, rank: score(song, tokens, raw) })
  }

  hits.sort(function (a, b) {
    if (a.rank !== b.rank) return a.rank - b.rank
    return a.song.no < b.song.no ? -1 : 1
  })

  var out = []
  var max = limit || hits.length
  for (var h = 0; h < hits.length && h < max; h++) out.push(hits[h].song)
  return out
}

// Hymn numbers are mostly "001".."333", but hymn 44 ships as "044e"/"044i" and
// there is a "238A" — so pad the digits and keep any suffix, case-insensitively.
function canonicalNumber(number) {
  var raw = String(number || "").trim()
  var match = /^(\d+)([A-Za-z]*)$/.exec(raw)
  if (!match) return raw.toLowerCase()
  var digits = match[1]
  while (digits.length < 3) digits = "0" + digits
  return (digits + match[2]).toLowerCase()
}

function indexOfNumber(songs, number) {
  var wanted = canonicalNumber(number)
  for (var i = 0; i < songs.length; i++) {
    if (songs[i].no.toLowerCase() === wanted) return i
  }
  return -1
}

// Which stanza the audio is currently inside. Cues are sorted ascending by
// sync.py, so the last cue at or before `seconds` wins. Returns 0 when the
// track has no cues or has not reached the first one.
function partAt(cues, seconds) {
  if (!cues || cues.length === 0) return 0
  var current = 0
  for (var i = 0; i < cues.length; i++) {
    if (cues[i].t <= seconds) current = cues[i].part
    else break
  }
  return current
}

// Start time of the first cue pointing at `part`, or -1 when unknown.
function timeOfPart(cues, part) {
  if (!cues) return -1
  for (var i = 0; i < cues.length; i++) if (cues[i].part === part) return cues[i].t
  return -1
}

function formatTime(millis) {
  if (!millis || millis < 0) return "0:00"
  var total = Math.floor(millis / 1000)
  var minutes = Math.floor(total / 60)
  var seconds = total % 60
  return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
}
