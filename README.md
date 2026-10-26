# NusaMac

Notch hidup untuk macOS: pil kecil di tengah atas layar yang mengembang
saat di-hover atau diklik, menampilkan musik + lirik tersinkron, timer
fokus Pomodoro, pengingat minum, rak file, daftar tugas, dan status sistem
(baterai, Wi-Fi).

> **Catatan clean-room.** NusaMac adalah implementasi independen yang
> terinspirasi oleh daftar fitur *publik* aplikasi Nusa (Windows) — bukan
> fork, bukan port dari kodenya. Nusa adalah aplikasi closed-source karya
> rama2555; tidak ada satu baris kode pun, aset, atau ikonnya yang dipakai
> di sini. **NusaMac tidak berafiliasi dengan rama2555 maupun proyek Nusa.**

## Fitur (v1)

- **Notch mengembang** — pil 32 pt (atau setinggi notch di MacBook
  ber-notch) menampilkan jam + lagu yang sedang diputar; hover/klik
  mengembangkannya menjadi panel 380 × 320 pt.
- **Musik** — judul/artis/album, progress bar, play/pause dan next, dari
  aplikasi Music atau Spotify lewat AppleScript.
- **Lirik** — lirik tersinkron dari LRCLIB, baris yang sedang dinyanyikan
  disorot dan di-scroll otomatis.
- **Fokus** — Pomodoro 25 menit fokus / 5 menit istirahat, hitungan siklus
  harian, notifikasi saat fase berganti.
- **Air** — target harian (default 8 gelas), tombol catat gelas, pengingat
  tiap jam pada 08.00–21.00 selama target belum tercapai.
- **Rak** — seret file ke panel untuk menyimpannya; hanya lokasinya yang
  dicatat, file tidak disalin. Klik ikon folder untuk membuka di Finder,
  seret keluar untuk memakainya di tempat lain.
- **Tugas** — tambah, centang, hapus; tersimpan lokal.
- **Status** — persentase baterai + status mengisi, dan SSID Wi-Fi di
  kaki panel. Jika tidak bisa dibaca, tampil tanda strip — bukan angka
  karangan.
- **Menu bar** — tampilkan/sembunyikan notch, toggle "Jalankan saat
  login", keluar. Aplikasi tidak punya ikon Dock (LSUIElement).

## Kebutuhan

- macOS 13 atau lebih baru (Apple Silicon maupun Intel).
- Untuk build dari source: Xcode Command Line Tools (`swift` tersedia).

## Build lokal

```sh
./build.sh
```

Hasilnya: `NusaMac.dmg` di folder yang sama. Tidak ada dependensi
eksternal — tidak ada package Swift yang diunduh, jadi build bekerja
offline selama toolchain Swift tersedia.

## Install

1. Buka `NusaMac.dmg`, seret `NusaMac.app` ke folder Applications.
2. **Peluncuran pertama (build unsigned):** karena aplikasi ini tidak
   ditandatangani dengan akun Apple Developer, macOS akan memblokirnya
   dengan pesan "cannot be opened because the developer cannot be
   verified". Jalankan dengan klik kanan pada `NusaMac.app` → **Open**,
   lalu konfirmasi **Open** pada dialog. Atau, dari Terminal:
   ```sh
   xattr -cr /Applications/NusaMac.app
   ```
3. Saat pertama kali memutar musik, macOS meminta izin Automation
   ("NusaMac ingin mengontrol Music/Spotify") — izinkan agar tab Musik
   dan Lirik bekerja. Jika ditolak, kedua tab hanya menampilkan status
   "tidak ada lagu"; tidak ada error, tidak ada crash. Izin bisa diubah
   di System Settings → Privacy & Security → Automation.
4. Izinkan notifikasi agar pengingat Pomodoro dan air muncul.

## Privasi

- Semua data (tugas, rak, hitungan air, siklus fokus, pengaturan) hanya
  tersimpan lokal di Mac lewat UserDefaults. Tidak ada akun, analitik,
  atau pelacakan.
- Satu-satunya data yang keluar dari Mac: saat tab Lirik memuat lirik,
  judul lagu, artis, album, dan durasi dikirim ke LRCLIB (lrclib.net)
  — persis seperti yang diungkapkan Nusa untuk fitur liriknya.
- Aplikasi tidak merekam ketikan dan tidak membaca isi file di rak;
  rak hanya menyimpan path file.

## Keterbatasan v1 yang disengaja

- Tidak ada overlay volume/kecerahan, notifikasi Caps Lock/bahasa
  keyboard, status headphone, grafik asupan air, pengingat bertenggat
  untuk tugas, mode notch minimal, atau ikon aplikasi kustom. Lihat
  `BUILD-NOTES.md` untuk daftar lengkapnya.
- Build ini unsigned: pengguna lain akan melihat peringatan Gatekeeper
  seperti di atas. Build bertanda tangan membutuhkan akun Apple
  Developer dan tidak termasuk dalam v1 ini.
