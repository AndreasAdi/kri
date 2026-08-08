#!/usr/bin/env python3
"""Fetch the KRI (Kidung Reformed Injili) hymnal sheet and normalize it to JSON.

The upstream data is a Google Sheet published as CSV by GRII and consumed by
https://kri.grii.online/. It is wide and sparse: lyrics live in up to 12 parts
of up to 14 lines each, spread across ~170 columns. This flattens that into one
record per hymn so the QML side never has to parse a CSV.

Writes atomically: the live songs.json is only replaced once the fetch produced
a plausible hymnal, so a broken upstream can never destroy a good cache.
"""

import csv
import json
import os
import re
import sys
import unicodedata
import urllib.error
import urllib.request

CSV_URL = (
    "https://docs.google.com/spreadsheets/d/e/2PACX-1vQqfRG03F7ovegIK6aiNGEZ"
    "baArjZeq3DeEjJO8sZH5qnTB4ENlt8VX44Usa2C-Ci8k0utFYfITI8YV/pub?output=csv"
)

# Upstream ships 333 hymns. Anything far below that means we fetched an error
# page or a truncated response, and must not overwrite a working cache.
MIN_SONGS = 300

MAX_PARTS = 12
MAX_LINES = 14


def fold(text):
    """Lowercase, strip accents and punctuation — the form both sides search on.

    Must stay byte-for-byte compatible with fold() in plugin/Songs.js, or the
    prebuilt `search` blob and the runtime query will not agree.
    """
    text = unicodedata.normalize("NFKD", str(text or ""))
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return text.strip()


def parse_parts(row):
    """Collect PartNLineNN columns into a list of stanzas, dropping trailing blanks."""
    parts = []
    for p in range(1, MAX_PARTS + 1):
        lines = []
        for line in range(1, MAX_LINES + 1):
            value = (row.get("Part%dLine%02d" % (p, line)) or "").strip()
            lines.append(value)
        while lines and not lines[-1]:
            lines.pop()
        if lines:
            parts.append(lines)
    return parts


def parse_cues(row):
    """Pair AudioTime ("0,55,99") with AudioInfo ("1,2,3") into karaoke cues.

    Upstream is hand-maintained, so the two columns are not guaranteed to be the
    same length; we keep only the pairs that line up and stay monotonic.
    """
    times = [t.strip() for t in (row.get("AudioTime") or "").split(",") if t.strip()]
    parts = [p.strip() for p in (row.get("AudioInfo") or "").split(",") if p.strip()]
    cues = []
    for raw_time, raw_part in zip(times, parts):
        try:
            seconds = float(raw_time)
            part = int(raw_part)
        except ValueError:
            continue
        if part < 1:
            continue
        if cues and seconds < cues[-1]["t"]:
            continue
        cues.append({"t": seconds, "part": part})
    return cues


def build_song(row):
    number = (row.get("NomorLagu") or "").strip()
    # "000" is the sheet's own template row, not a hymn.
    if not number or number == "000":
        return None

    title = (row.get("JudulLagu") or "").strip()
    parts = parse_parts(row)

    haystack = [number, str(int(number)) if number.isdigit() else number, title]
    haystack += [
        (row.get("HymnTune") or "").strip(),
        (row.get("Lyric") or "").strip(),
        (row.get("Music") or "").strip(),
    ]
    for stanza in parts:
        haystack.extend(stanza)

    return {
        "no": number,
        "title": title,
        "keyTime": (row.get("KeyTime") or "").strip(),
        "hymnTune": (row.get("HymnTune") or "").strip(),
        "lyric": (row.get("Lyric") or "").strip(),
        "music": (row.get("Music") or "").strip(),
        "parts": parts,
        "media": (row.get("MediaLink") or "").strip(),
        "cues": parse_cues(row),
        "titleFold": fold(title),
        "search": fold(" ".join(haystack)),
    }


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "kri-sync/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8", errors="replace")


def main():
    data_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.local/share/kri")
    target = os.path.join(data_dir, "songs.json")
    os.makedirs(data_dir, exist_ok=True)

    try:
        raw = fetch(CSV_URL)
    except (urllib.error.URLError, TimeoutError) as err:
        print("kri: fetch failed: %s" % err, file=sys.stderr)
        return 1

    reader = csv.DictReader(raw.splitlines())
    songs = [song for song in (build_song(row) for row in reader) if song]

    if len(songs) < MIN_SONGS:
        print(
            "kri: refusing to write — got %d songs, expected at least %d. "
            "Existing cache left untouched." % (len(songs), MIN_SONGS),
            file=sys.stderr,
        )
        return 1

    songs.sort(key=lambda s: s["no"])

    tmp = target + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(songs, handle, ensure_ascii=False, separators=(",", ":"))
    os.replace(tmp, target)

    with_audio = sum(1 for s in songs if s["media"])
    with_cues = sum(1 for s in songs if s["cues"])
    print("kri: %d songs, %d with audio, %d with karaoke cues -> %s"
          % (len(songs), with_audio, with_cues, target))
    return 0


if __name__ == "__main__":
    sys.exit(main())
