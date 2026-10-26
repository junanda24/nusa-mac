import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var notch: NotchController

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: notch.isExpanded ? 20 : 16)
                .fill(Color.black.opacity(0.92))
            if notch.isExpanded {
                ExpandedView()
            } else {
                CollapsedView()
            }
        }
        .frame(
            width: notch.isExpanded ? NotchController.expandedSize.width : NotchController.collapsedSize.width,
            height: notch.isExpanded ? NotchController.expandedSize.height : notch.collapsedHeight
        )
    }
}

// MARK: - Collapsed pill

enum MascotState {
    case sleeping
    case happy
}

/// The idle mascot: a small drawn face, nothing more. Eyes are closed lines
/// while idle, open dots while music plays.
struct MascotFace: View {
    let state: MascotState

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12))
            HStack(spacing: 4) {
                eye
                eye
            }
        }
        .frame(width: 20, height: 20)
    }

    private var eye: some View {
        Group {
            if state == .sleeping {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 5, height: 1.5)
            } else {
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
            }
        }
    }
}

struct CollapsedView: View {
    @EnvironmentObject var notch: NotchController
    @EnvironmentObject var nowPlaying: NowPlayingService

    var body: some View {
        Button(action: { notch.togglePinned() }) {
            HStack(spacing: 8) {
                MascotFace(state: mascotState)
                TimelineView(.periodic(from: Date(), by: 30)) { timeline in
                    Text(timeline.date, style: .time)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                if let track = nowPlaying.track {
                    Text(verbatim: "\(track.title) — \(track.artist)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private var mascotState: MascotState {
        if let track = nowPlaying.track, track.isPlaying {
            return .happy
        }
        return .sleeping
    }
}

// MARK: - Expanded

struct ExpandedView: View {
    @EnvironmentObject var notch: NotchController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NusaMac")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { notch.closeExpanded() }) {
                    Image(systemName: "chevron.up")
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Picker("Tampilan", selection: $notch.selectedTab) {
                ForEach(NotchController.NotchTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)

            TabContentView()
                .padding(12)

            Spacer(minLength: 0)

            StatusPeekRow()
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }
}

struct TabContentView: View {
    @EnvironmentObject var notch: NotchController

    var body: some View {
        switch notch.selectedTab {
        case .music:
            MusicView()
        case .lyrics:
            LyricsTabView()
        case .focus:
            FocusView()
        case .water:
            WaterView()
        case .shelf:
            ShelfView()
        case .todos:
            TodosView()
        }
    }
}

// MARK: - Shared bits

func formatTime(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    return String(format: "%d:%02d", total / 60, total % 60)
}

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: geometry.size.width * CGFloat(max(0, min(1, progress))))
            }
        }
        .frame(height: 4)
    }
}

struct StatusPeekRow: View {
    @EnvironmentObject var system: SystemStatus

    var body: some View {
        HStack(spacing: 12) {
            if let percent = system.batteryPercent {
                Image(systemName: system.isCharging ? "battery.100.bolt" : "battery.75")
                Text("\(percent)%\(system.isCharging ? " · Mengisi" : "")")
            } else {
                Image(systemName: "battery")
                Text("Baterai —")
            }
            Spacer()
            Image(systemName: "wifi")
            if let ssid = system.wifiSSID {
                Text(verbatim: ssid)
            } else {
                Text("Wi-Fi —")
            }
        }
        .font(.caption)
        .foregroundColor(.white.opacity(0.7))
    }
}

// MARK: - Music tab

struct MusicView: View {
    @EnvironmentObject var nowPlaying: NowPlayingService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let track = nowPlaying.track {
                Text(verbatim: track.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(verbatim: track.album.isEmpty ? track.artist : "\(track.artist) · \(track.album)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                ProgressBar(progress: track.progress)
                HStack {
                    Text(formatTime(track.position))
                    Spacer()
                    Text(formatTime(track.duration))
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                HStack(spacing: 20) {
                    Button(action: { nowPlaying.togglePlayPause() }) {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                    }
                    Button(action: { nowPlaying.nextTrack() }) {
                        Image(systemName: "forward.fill")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .font(.title3)
            } else {
                Text("Tidak ada lagu yang diputar")
                    .foregroundColor(.white.opacity(0.85))
                Text("Putar musik di Music atau Spotify, dan NusaMac akan menampilkannya di sini. Saat pertama kali, macOS akan meminta izin untuk mengontrol aplikasi tersebut — izinkan agar fitur ini bekerja.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lyrics tab

struct LyricsTabView: View {
    @EnvironmentObject var lyrics: LyricsService
    @EnvironmentObject var nowPlaying: NowPlayingService

    var body: some View {
        Group {
            switch lyrics.state {
            case .idle:
                Text("Putar lagu untuk melihat liriknya.")
                    .foregroundColor(.white.opacity(0.7))
            case .loading:
                Text("Mencari lirik…")
                    .foregroundColor(.white.opacity(0.7))
            case .unavailable:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lirik tidak tersedia")
                        .foregroundColor(.white)
                    Text("Lagu ini belum punya lirik tersinkron di LRCLIB, atau jaringan sedang bermasalah.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            case .available(let lines):
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(lines) { line in
                                Text(verbatim: line.text.isEmpty ? "…" : line.text)
                                    .font(.system(
                                        size: 14,
                                        weight: isCurrent(line, in: lines) ? .bold : .regular
                                    ))
                                    .foregroundColor(isCurrent(line, in: lines) ? .white : .white.opacity(0.45))
                                    .id(line.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onReceive(lyrics.$currentIndex) { index in
                        guard let index = index, lines.indices.contains(index) else { return }
                        withAnimation {
                            proxy.scrollTo(lines[index].id, anchor: .center)
                        }
                    }
                    .onReceive(nowPlaying.$track) { track in
                        lyrics.updateCurrentIndex(position: track?.position ?? 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isCurrent(_ line: LyricLine, in lines: [LyricLine]) -> Bool {
        guard let index = lyrics.currentIndex,
              lines.indices.contains(index) else { return false }
        return lines[index].id == line.id
    }
}

// MARK: - Focus tab

struct FocusView: View {
    @EnvironmentObject var pomodoro: PomodoroStore

    var body: some View {
        VStack(spacing: 12) {
            Text(pomodoro.phase == .focus ? "Fokus" : "Istirahat")
                .font(.headline)
                .foregroundColor(.white)
            Text(pomodoro.timeText)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
            HStack(spacing: 12) {
                Button(pomodoro.isRunning ? "Jeda" : "Mulai") { pomodoro.startPause() }
                Button("Atur Ulang") { pomodoro.reset() }
            }
            .buttonStyle(.bordered)
            Text("Siklus selesai hari ini: \(pomodoro.completedCycles)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Water tab

struct WaterView: View {
    @EnvironmentObject var water: WaterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(water.glassesToday) / \(water.dailyGoal) gelas hari ini")
                .font(.headline)
                .foregroundColor(.white)
            ProgressBar(progress: water.dailyGoal > 0
                ? Double(water.glassesToday) / Double(water.dailyGoal)
                : 0)
            HStack(spacing: 12) {
                Button("Minum 1 gelas") { water.logGlass() }
                Button("Batalkan") { water.removeGlass() }
                    .disabled(water.glassesToday == 0)
            }
            .buttonStyle(.bordered)
            HStack {
                Text("Target harian: \(water.dailyGoal) gelas")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Button(action: { water.setGoal(water.dailyGoal - 1) }) {
                    Image(systemName: "minus")
                }
                Button(action: { water.setGoal(water.dailyGoal + 1) }) {
                    Image(systemName: "plus")
                }
            }
            .buttonStyle(.bordered)
            Text("Pengingat muncul tiap jam pada 08.00–21.00 selama target belum tercapai.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shelf tab

struct ShelfView: View {
    @EnvironmentObject var shelf: ShelfStore
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundColor(isDropTarget ? .white : .white.opacity(0.4))
                    .frame(height: 56)
                Text("Seret file ke sini")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
                var paths: [String] = []
                let group = DispatchGroup()
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        DispatchQueue.main.async {
                            if let url = url {
                                paths.append(url.path)
                            }
                            group.leave()
                        }
                    }
                }
                group.notify(queue: .main) {
                    shelf.add(paths: paths)
                }
                return true
            }
            if shelf.items.isEmpty {
                Text("Rak masih kosong. File yang kamu seret hanya dicatat lokasinya, bukan disalin.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(shelf.items) { item in
                            HStack {
                                Text(verbatim: item.name)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                                Spacer()
                                if item.exists {
                                    Button(action: { shelf.reveal(item) }) {
                                        Image(systemName: "folder")
                                    }
                                }
                                Button(action: { shelf.remove(item) }) {
                                    Image(systemName: "trash")
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white.opacity(0.85))
                            .onDrag {
                                NSItemProvider(object: item.url as NSURL)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Todos tab

struct TodosView: View {
    @EnvironmentObject var todos: TodoStore
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Tugas baru…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { add() }
                Button("Tambah") { add() }
                    .buttonStyle(.bordered)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if todos.items.isEmpty {
                Text("Belum ada tugas.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(todos.items) { item in
                            HStack {
                                Button(action: { todos.toggle(item) }) {
                                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                }
                                .buttonStyle(.plain)
                                Text(verbatim: item.title)
                                    .strikethrough(item.isDone)
                                    .foregroundColor(item.isDone ? .white.opacity(0.5) : .white)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: { todos.delete(item) }) {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add() {
        todos.add(title: draft)
        draft = ""
    }
}
