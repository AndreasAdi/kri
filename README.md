# KRI — Kidung Reformed Injili untuk Omarchy

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

```bash
git clone <repo> ~/Projects/kri
cd ~/Projects/kri
./bin/kri install                  # link plugin + CLI
omarchy plugin enable andreas.kri right
./bin/kri sync                     # unduh hymnal (~700 KB)
```

Lalu tambahkan keybinding di `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + K", "Kidung Reformed Injili", "omarchy-shell shell toggle andreas.kri '{}'")
o.bind("SUPER + SHIFT + ALT + K", "Kidung play/pause", "omarchy-shell kri toggle")
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
tampil utuh. Perubahan langsung terlihat tanpa restart shell. Bar vertikal
otomatis jadi nomor-saja.

## Arsitektur

```
bin/kri              CLI: sync, cache audio, resolusi path
lib/sync.py          CSV Google Sheet → songs.json ternormalisasi
plugin/
  manifest.json      kinds: service + overlay + bar-widget
  Service.qml        singleton: data, MediaPlayer, jam karaoke, IPC target "kri"
  Overlay.qml        UI cari + lirik + kontrol
  BarWidget.qml      pill now-playing
  Songs.js           pencarian, normalisasi nomor, pemetaan cue → bait
```

Pembagian kerjanya: Bash/Python mengurus jaringan dan disk, QML mengurus
tampilan dan sinkronisasi audio. Service adalah satu-satunya pemilik state —
overlay dan bar widget hanya membacanya, itulah sebabnya audio tetap jalan
setelah overlay ditutup.

### Sumber data

Google Sheet publik milik GRII yang juga dipakai <https://kri.grii.online/>,
plus MP3 di `stor.grii.online`. Sekali sync menghasilkan 335 entri untuk 333
nomor kidung — nomor 44 terbit dalam dua versi (`044e` Inggris, `044i`
Indonesia) dan ada satu `238A`. 272 kidung punya audio, 270 punya timestamp bait.

`sync.py` menulis secara atomik dan menolak menimpa cache yang sehat kalau
hasil fetch mencurigakan, jadi upstream yang rusak tidak bisa merusak data lokal.
Unduhan audio juga divalidasi (tipe MIME + ukuran) karena sebagian URL upstream
mengembalikan stub — `KRI-333.mp3` misalnya hanya 94 byte.

### Catatan pengembangan

Sumbernya ada di repo ini; `~/.config/omarchy/plugins/andreas.kri` hanyalah
symlink ke `plugin/`. Penemuan plugin mengikuti symlink, tetapi watcher inotify
milik Omarchy tidak — dan `rescanPlugins` pun tidak cukup karena QML masih
dilayani dari component cache Qt dan singleton `Service.qml` hanya dibuat sekali.
Karena itu `kri dev` me-restart shell (~2 detik) setiap kali file disimpan.

## Catatan

Data ini dipublikasikan GRII untuk diakses umum. Aplikasi ini untuk pemakaian
pribadi; jangan distribusikan ulang berikut berkas audionya.
