# BUILD-NOTES — NusaMac

Catatan ini dibuat karena kode ini ditulis di mesin Linux dan **belum
pernah dikompilasi**. Compiler pertamanya adalah macOS runner di CI.
Bagian 1 berisi semua API/pola yang paling tidak pasti — periksa bagian
ini dulu saat membaca log kegagalan CI. Bagian 2 berisi yang sengaja
tidak dibuat.

## 1. API yang paling tidak pasti (urut dari yang paling berisiko)

1. **`@main` pada class AppDelegate + `static func main()` + `NSApplication.run()`**
   (Sources/NusaMac/AppDelegate.swift). Pola ini dipakai aplikasi AppKit
   berbasis SPM, tapi bukan pola paling umum (umumnya `main.swift` +
   `NSApplicationMain`). Risiko: compiler menolak `@main` pada class
   tanpa `main.swift`, atau `run()` tanpa `NSApplicationMain` melewatkan
   langkah init. Penahan: delegate disimpan di `retainedDelegate` statis
   karena properti `delegate` NSApplication tidak me-retain. Jika CI
   menolak pola ini, fallback-nya adalah menambah `main.swift` —
   tetapi itu melanggar spek awal, jadi laporkan dulu sebelum memakai
   fallback tersebut.
2. **Klik pertama pada tombol SwiftUI di window borderless**
   (NotchWindow.swift: `canBecomeKey = true` + `ClickThroughHostingView`
   yang meng-override `acceptsFirstMouse`). Perilaku klik pertama di
   window yang belum key bergantung pada hit view internal SwiftUI,
   yang mungkin tidak menghormati override di hosting view. Gejala
   yang mungkin: pil perlu diklik dua kali untuk membuka. Verifikasi
   di Mac asli. Fallback: jadikan `NotchWindow` subclass `NSPanel`
   dengan style `.nonactivatingPanel` (klik tembus tanpa aktivasi) —
   tetapi itu mengubah superclass, jadi laporkan dulu.
3. **`NSWindow.safeAreaInsets` pada window borderless**
   (NotchWindow.swift, NotchController.reposition). Inset ini hanya
   valid setelah window tampil; `reposition()` dipanggil setelah
   `orderFront`, dan nilai 0 hanya membuat pil tetap 32 pt — tidak
   merusak apa pun. Risiko rendah, tapi deteksi notch belum teruji.
4. **CoreWLAN: `CWWiFiClient.shared().interface()?.ssid()`**
   (SystemStatus.swift). API-nya stabil, tapi di macOS baru SSID bisa
   dibatasi izin/entitlement dan mengembalikan nil. Sudah dijaga:
   nil → tampil strip. Risiko rendah.
5. **IOKit: `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList` /
   `IOPSGetPowerSourceDescription` + cast `CFDictionary as? [String: Any]`**
   (SystemStatus.swift). Aturan Copy vs Get dipakai
   (`takeRetainedValue` untuk Copy, `takeUnretainedValue` untuk Get).
   Jika cast gagal, baterai tampil strip. Risiko rendah.
6. **AppleScript Music vs Spotify** (NowPlaying.swift). Perbedaan yang
   ditangani: durasi Music dalam detik, Spotify dalam milidetik;
   `player state` berupa "playing"/"paused"/"stopped"; `stopped`
   diperlakukan sebagai "tidak ada lagu". `tell` hanya dikirim ke
   aplikasi yang terdeteksi berjalan via `NSWorkspace` (agar aplikasi
   tidak ikut terbuka). Jika pengguna menolak izin Automation,
   `executeAndReturnError` mengembalikan error dan hasilnya nil —
   tidak ada modal, tidak ada crash. Perlu dicek di Mac asli bahwa
   skrip tidak salah parsing (pemakaian `return` sebagai pemisah
   baris, karena AppleScript tidak mengenal escape `"\n"`).
7. **SwiftUI drag & drop** (Views.swift, ShelfView). `loadObject(ofClass:
   URL.self)` mengandalkan bridging URL↔NSURL untuk
   `NSItemProviderReading`, dan `.onDrag` mengandalkan `NSURL`
   sebagai `NSItemProviderWriting`. Keduanya pola umum, tapi belum
   teruji di sini. Jika gagal compile, gantinya adalah
   `loadItem(forTypeIdentifier: UTType.fileURL.identifier)`.
8. **`SMAppService.mainApp` untuk launch-at-login** (StatusBar.swift).
   Hanya bekerja di dalam app bundle; di bawah `swift run` akan
   throw dan ditangkap — menu tetap menampilkan status sebenarnya.
   Di .app hasil build.sh seharusnya bekerja.
9. **Animasi frame vs konten** (NotchController). Window dianimasikan
   lewat `window.animator().setFrame`, tetapi konten SwiftUI berganti
   ukuran seketika (snap) mengikuti `isExpanded`. Hasil: frame
   meluncur mulus, isi panel muncul langsung. Ini kosmetik, bukan
   error. Perbaikan kelak: animasikan juga hosting view.
10. **`.linkedFramework` di Package.swift.** Entri eksplisit untuk
    AppKit, IOKit, CoreWLAN, ServiceManagement, UserNotifications.
    Jika toolchain sudah auto-link framework Apple (yang umum terjadi),
    entri ini redundan tapi tidak berbahaya.
11. **`hdiutil create -format UDZO` + ad-hoc `codesign --sign -`**
    (build.sh). Standar di runner macOS; jika `codesign` gagal karena
    alasan lingkungan, CI gagal cepat di langkah ini.
12. **LRCLIB** (LyricsService.swift). Endpoint `GET /api/search` lalu
    `GET /api/get/:id` dipakai sesuai spek; respons search sudah
    mengandung `syncedLyrics` sehingga `/api/get` hanya dipanggil
    bila hasil search tidak punya lirik tersinkron. Kegagalan jaringan
    apa pun → status `.unavailable` → UI "lirik tidak tersedia".
13. **API lain yang dipakai dan dianggap aman:** `NSStatusItem`,
    `NSMenu`/`NSMenuItem`, `UNUserNotificationCenter`,
    `NSWorkspace.activateFileViewerSelecting`,
    `TimelineView(.periodic)` (macOS 12+, target kita 13+),
    `TextField(onCommit:)`, `Picker` segmented, `Label`, SF Symbols.
    Semuanya API stabil macOS 13+.

## 2. Yang sengaja tidak dibuat di v1

- Overlay volume/kecerahan, nudge Caps Lock dan perubahan bahasa
  keyboard, status headphone — semuanya ada di Nusa Windows, tapi
  membutuhkan pemantauan event sistem yang lebih invasif; ditunda.
- Grafik asupan air dan ukuran botol — v1 hanya hitungan gelas +
  target harian.
- Pengingat bertenggat untuk tugas — v1 hanya tambah/centang/hapus.
- Mode notch minimal (garis tipis) dari tray menu Nusa.
- Animasi maskot melambai — v1 hanya wajah sederhana (mata tertutup
  saat idle, mata terbuka saat musik diputar).
- Ikon aplikasi kustom — .app tidak punya `CFBundleIconFile`; macOS
  memakai ikon generik. Tambahkan nanti via `Contents/Resources/` +
  kunci `CFBundleIconFile`.
- Tidak ada file entitlements — aplikasi sengaja unsandboxed agar rak
  file bisa memakai path secara langsung (sesuai spek).
- Tidak ada kunci `NSAppleScriptEnabled` di Info.plist — kunci itu
  bukan mekanisme izin yang benar; yang benar adalah
  `NSAppleEventsUsageDescription` (sudah ada) + izin Automation
  runtime yang diminta sistem saat pertama kali.
- UI hanya berbahasa Indonesia (mengikuti audiens Nusa); belum ada
  toggle EN/ID seperti situs Nusa.
