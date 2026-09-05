# KRI — Kidung Reformed Injili untuk Omarchy

*An Omarchy shell plugin for the 333 hymns of the Indonesian Reformed
Evangelical Church: search, lyrics, and karaoke-style singalong.*

Akses 333 kidung GRII langsung dari desktop: cari, baca lirik, dengarkan, dan
ikuti nyanyian dengan sorotan bait yang bergerak mengikuti audio.

Dibangun sebagai plugin [Quickshell](https://quickshell.org/) di dalam
`omarchy-shell`, jadi overlay-nya terbuka instan (~30 ms) dan ikut berganti
warna setiap kali tema Omarchy diganti.

```
┌─ SUPER+SHIFT+K ─────────────────────────────────────────────┐
│ Cari nomor, judul, atau lirik…  │ KRI 001 · Besarlah Allahku │
│ 335 dari 335 kidung             │ 1=C 4/4 · O STORE GUD      │
│ ▸ 001 Besarlah Allahku       ♪  │                            │
│   002 Agungkan Kuasa Nama-Nya   │ 1  O Tuhanku, bila ku …    │
│   003 Terpujilah Nama Yesus     │ 2  Ya Tuhanku, 'pabila …   │
│   …                             │ ▓3 'Pabila nanti Kristus…▓ │  ← bait aktif
│                                 │ ▶ KRI 001  2:07 / 2:28     │
└─────────────────────────────────────────────────────────────┘
```

## Fitur

- **Pencarian instan** atas nomor, judul, hymn tune, pengarang, dan seluruh lirik
- **Mode karaoke** — bait yang sedang dinyanyikan disorot dan digulir otomatis,
  memakai timestamp per bait yang sudah tersedia di data GRII
- **Layar penuh** — `F11` di dalam overlay, atau `kri present [nomor]` langsung.
  Lirik memenuhi layar dengan ukuran yang bisa diatur, pencarian disembunyikan,
  dan tombol huruf tidak lagi mengetik apa pun sehingga tampilan aman dari
  tekanan tombol yang tak sengaja
- **Ulang lagu** — `Ctrl+R` untuk melooping kidung yang sedang diputar; berguna
  untuk menghafal nada atau menahan satu kidung selama ibadah
- **Widget bar** — kidung yang sedang diputar, dengan kontrol klik dan scroll
- **Offline** — lirik selalu offline; audio tersimpan otomatis begitu diputar,
  atau borong sekaligus dengan `kri download --all`

## Instalasi

Butuh Omarchy 4 atau lebih baru.

```bash
omarchy plugin add https://github.com/AndreasAdi/kri.git --enable
~/.config/omarchy/plugins/andreas.kri/bin/kri setup
```

`omarchy plugin add` meng-clone repo ini ke `~/.config/omarchy/plugins/andreas.kri/`
dan menyalakan widget bar-nya. `kri setup` menautkan CLI ke `~/.local/bin` lalu
mengunduh data kidungnya (~700 KB) — atau lewati saja dan tekan tombol **Unduh
333 kidung** yang muncul di overlay saat pertama kali dibuka.

Pembaruan lewat jalur yang sama:

```bash
omarchy plugin update andreas.kri
```

Lalu tambahkan keybinding di `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + K", "Kidung Reformed Injili", "omarchy-shell shell toggle andreas.kri '{}'")
o.bind("SUPER + SHIFT + ALT + K", "Kidung play/pause", "omarchy-shell kri toggle")
```

Opsional, baris menu di `~/.config/omarchy/extensions/omarchy-menu.jsonc`.
Perhatikan bahwa baris menu dijalankan lewat `bash -lc` yang PATH-nya tidak
memuat `~/.local/bin`, jadi panggil CLI-nya lewat path pluginnya langsung:

```jsonc
"kri": {"icon":"󰎇","label":"Kidung Reformed Injili","aliases":["kidung","hymn"]},
"kri.open": {"icon":"󰍉","label":"Buka pencarian","action":"omarchy-shell shell toggle andreas.kri '{}'"},
"kri.present": {"icon":"󰊔","label":"Layar penuh","action":"$HOME/.config/omarchy/plugins/andreas.kri/bin/kri present"},
"kri.toggle": {"icon":"󰐊","label":"Putar / jeda","action":"omarchy-shell kri toggle"},
"kri.repeat": {"icon":"󰑖","label":"Ulang lagu","action":"omarchy-shell kri repeat","checked":"omarchy-shell kri status | grep -q repeat"},
"kri.download": {"icon":"󰇚","label":"Unduh semua audio","action":"$HOME/.config/omarchy/plugins/andreas.kri/bin/kri download --all"},
```

## Pintasan di dalam overlay

| Tombol | Aksi |
|---|---|
| ketik apa saja | cari nomor / judul / lirik |
| `↑` `↓` | pilih kidung |
| `Enter` | putar |
| `Ctrl+Space` | putar / jeda |
| `Ctrl+←` `Ctrl+→` | lompat bait sebelumnya / berikutnya |
| `Ctrl+N` `Ctrl+P` | kidung berikutnya / sebelumnya |
| `Ctrl+R` | ulang lagu on/off |
| `Ctrl+K` | ikuti audio (auto-scroll) on/off |
| `Ctrl+U` / `Backspace` | hapus pencarian |
| `F11` / `Ctrl+F` | layar penuh on/off |
| `Esc` | keluar layar penuh → kosongkan pencarian → tutup |

Klik satu bait untuk melompat ke bagian itu di audio.

Di **layar penuh** pencarian tidak aktif, jadi tombol tak perlu `Ctrl`:

| Tombol | Aksi |
|---|---|
| `Space` | putar / jeda |
| `←` `→` `↑` `↓` | gulir lirik |
| `Ctrl+←` `Ctrl+→` | lompat bait (seek audio) |
| `R` | ulang lagu on/off |
| `+` `−` | perbesar / perkecil lirik |
| `0` | kembalikan ukuran |
| `F11` / `Esc` | keluar dari layar penuh |

Tombol lain diabaikan — tampilan tidak bisa terganggu ketikan yang tak sengaja.

## CLI

```bash
kri sync                 # ambil hymnal terbaru
kri download --all       # cache seluruh audio (~1,6 GB, 272 lagu)
kri download 001 044e    # cache lagu tertentu
kri path 24              # path lokal, atau URL kalau belum di-cache
kri doctor               # status cache, plugin, dan shell
kri setup                # daftarkan plugin, tautkan CLI, ambil data kidung
kri dev                  # pantau sumber plugin, restart shell tiap disimpan
kri present [nomor]      # buka langsung ke tampilan layar penuh
kri repeat [on|off]      # ulang lagu; tanpa argumen = toggle
kri open | play <no> | toggle | next | prev
```

## Mengatur widget bar

Judul yang kepanjangan **dipotong**, tidak digulir — 36% judul kidung melebihi
lebar bar, dan sebagian besar hanya kelebihan dua–tiga karakter, jadi animasi
gulir akan bergerak terus untuk mengungkap nyaris tidak ada apa-apa. Judul
penuh ada di tooltip. Nomor kidung tidak pernah ikut terpotong.

```bash
omarchy bar set andreas.kri titleDisplay number   # nomor saja: 󰎇 012
omarchy bar set andreas.kri titleDisplay elide    # default: 󰎇 012 Allah Baik
omarchy bar set andreas.kri maxLabelWidth 140     # potong lebih awal
omarchy bar set andreas.kri maxLabelWidth 300     # semua judul tampil utuh
```

Default `maxLabelWidth` 240px memuat ~33 karakter — 324 dari 335 judul (97%)
tampil utuh. Perubahan langsung terlihat tanpa restart shell.

### Bar vertikal

Di bar kiri/kanan hanya ada lebar 28px, jadi widget-nya berputar: not balok di
atas, nomor kidung di bawahnya, plus ikon ulang kalau lagi dilooping. Judulnya
tidak muat dalam bentuk apa pun, jadi ia tinggal di tooltip. Nomor diukur dan
diperkecil seperlunya, sehingga `044e` — nomor terpanjang di hymnal — tetap
muat utuh berapa pun ukuran font bar-nya.

```bash
omarchy bar set andreas.kri verticalDisplay icon     # not balok saja
omarchy bar set andreas.kri verticalDisplay number   # default: not + nomor
```

Layar penuh menutupi bar di posisi mana pun ia berada — overlay-nya satu lapis
di atas bar — jadi lirik memakai seluruh layar, bukan menyisakan pita kosong.

## Arsitektur

Akar repo ini *adalah* folder pluginnya — begitulah `omarchy plugin add` bekerja:
repo di-clone apa adanya ke `~/.config/omarchy/plugins/<id>/`, jadi
`manifest.json` harus ada di akar dan tidak boleh ada symlink di dalamnya.

```
manifest.json        kinds: service + overlay + bar-widget
qml/
  Service.qml        singleton: data, MediaPlayer, jam karaoke, IPC target "kri"
  Overlay.qml        UI cari + lirik + kontrol
  BarWidget.qml      pill now-playing
  Songs.js           pencarian, normalisasi nomor, pemetaan cue → bait
bin/kri              CLI: sync, cache audio, resolusi path
lib/sync.py          CSV Google Sheet → songs.json ternormalisasi
```

Pembagian kerjanya: Bash/Python mengurus jaringan dan disk, QML mengurus
tampilan dan sinkronisasi audio. Service adalah satu-satunya pemilik state —
overlay dan bar widget hanya membacanya, itulah sebabnya audio tetap jalan
setelah overlay ditutup.

CLI-nya ikut terbawa di dalam plugin, dan Service memanggilnya lewat path
absolut yang diambil dari `manifest.__sourceDir` — bukan lewat `$PATH`.
`omarchy plugin add` memang tidak punya cara memasang apa pun ke `$PATH`, jadi
plugin yang bergantung padanya akan ter-install tapi tidak bisa memutar apa-apa.
`~/.local/bin/kri` cuma kemudahan buat manusia.

### Sumber data

Google Sheet publik milik GRII yang juga dipakai <https://kri.grii.online/>,
plus MP3 di `stor.grii.online`. Sekali sync menghasilkan 335 entri untuk 333
nomor kidung — nomor 44 terbit dalam dua versi (`044e` Inggris, `044i`
Indonesia) dan ada satu `238A`. 272 kidung punya audio, 270 punya timestamp bait.

63 sisanya lirik saja. Memilihnya tetap menampilkan liriknya penuh, tapi tidak
mengambil alih pemutar — kidung yang sedang berjalan terus berbunyi, karena bar
hanya boleh menyebut apa yang benar-benar terdengar. `Ctrl+N`/`Ctrl+P` dan
scroll di bar melompatinya; `↑`/`↓` di overlay tetap menyusuri semuanya.

`sync.py` menulis secara atomik dan menolak menimpa cache yang sehat kalau
hasil fetch mencurigakan, jadi upstream yang rusak tidak bisa merusak data lokal.
Unduhan audio juga divalidasi (tipe MIME + ukuran) karena sebagian URL upstream
mengembalikan stub — `KRI-333.mp3` misalnya hanya 94 byte.

### Catatan pengembangan

Untuk mengembangkan tanpa mengedit di dalam `~/.config/omarchy/plugins/`,
clone ke mana saja lalu jalankan `./bin/kri setup`: ia menautkan
`~/.config/omarchy/plugins/andreas.kri` ke checkout tersebut. Penemuan plugin
mengikuti symlink, tetapi watcher inotify milik Omarchy tidak — dan
`rescanPlugins` pun tidak cukup karena QML masih dilayani dari component cache
Qt dan singleton `Service.qml` hanya dibuat sekali. Karena itu `kri dev`
me-restart shell (~2 detik) setiap kali file disimpan.

`kri setup` tahu keduanya: kalau dijalankan dari checkout yang sudah berada di
folder plugin (hasil `omarchy plugin add`), ia tidak menautkan apa pun.

Sebelum merilis, pastikan manifesnya lolos pemeriksaan yang sama dengan yang
dipakai installer:

```bash
omarchy plugin validate .
```

## Lisensi dan hak cipta

Kode di repo ini berlisensi MIT — lihat [LICENSE](LICENSE).

Lirik, not, dan rekamannya adalah milik GRII dan **tidak** ikut di repo ini.
Repo ini hanya berisi kode yang mengambilnya dari sumber publik GRII ke komputer
yang menjalankannya, jadi memasang plugin ini tidak mendistribusikan ulang
materi mereka — dan berkas audio yang sudah ter-cache di `~/.local/share/kri/`
juga jangan disebarkan.
