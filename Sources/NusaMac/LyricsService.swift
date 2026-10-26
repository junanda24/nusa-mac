import Combine
import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

enum LyricsState: Equatable {
    case idle
    case loading
    case available([LyricLine])
    case unavailable
}

/// Synced lyrics from LRCLIB (https://lrclib.net), a free community library.
/// No API key is needed. Only the track title, artist, album and duration are
/// sent to LRCLIB, exactly as Nusa (Windows) discloses for its own lyrics
/// feature. Any network failure lands in `.unavailable`, which the UI renders
/// honestly as "lirik tidak tersedia" — never a fake or placeholder lyric.
final class LyricsService: ObservableObject {
    @Published private(set) var state: LyricsState = .idle
    @Published private(set) var currentIndex: Int?

    private var cachedKey: String?
    private var cachedLines: [LyricLine] = []
    private var currentTask: URLSessionDataTask?

    func fetch(for track: Track?) {
        currentTask?.cancel()
        guard let track = track else {
            state = .idle
            currentIndex = nil
            cachedKey = nil
            cachedLines = []
            return
        }
        let key = track.cacheKey
        if key == cachedKey {
            state = .available(cachedLines)
            updateCurrentIndex(position: track.position)
            return
        }
        cachedKey = key
        state = .loading
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration)))
        ]
        guard let url = components.url else {
            state = .unavailable
            return
        }
        currentTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, self.cachedKey == key else { return }
            guard let data = data,
                  let results = try? JSONDecoder().decode([LRCLibResult].self, from: data),
                  !results.isEmpty else {
                DispatchQueue.main.async { self.state = .unavailable }
                return
            }
            if let withSynced = results.first(where: { !($0.syncedLyrics ?? "").isEmpty }),
               let synced = withSynced.syncedLyrics {
                self.finishFetch(syncedLyrics: synced, key: key)
            } else if let first = results.first, let id = first.id {
                self.fetchByID(id, key: key)
            } else {
                DispatchQueue.main.async { self.state = .unavailable }
            }
        }
        currentTask?.resume()
    }

    /// Called by the lyrics view as playback position advances.
    func updateCurrentIndex(position: TimeInterval) {
        guard case .available(let lines) = state else {
            currentIndex = nil
            return
        }
        var index: Int?
        for (i, line) in lines.enumerated() where line.time <= position {
            index = i
        }
        if index != currentIndex {
            currentIndex = index
        }
    }

    // MARK: - Private

    private struct LRCLibResult: Decodable {
        let id: Int?
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    private func fetchByID(_ id: Int, key: String) {
        guard let url = URL(string: "https://lrclib.net/api/get/\(id)") else {
            DispatchQueue.main.async { [weak self] in self?.state = .unavailable }
            return
        }
        currentTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, self.cachedKey == key else { return }
            guard let data = data,
                  let result = try? JSONDecoder().decode(LRCLibResult.self, from: data),
                  let synced = result.syncedLyrics, !synced.isEmpty else {
                DispatchQueue.main.async { self.state = .unavailable }
                return
            }
            self.finishFetch(syncedLyrics: synced, key: key)
        }
        currentTask?.resume()
    }

    private func finishFetch(syncedLyrics: String, key: String) {
        let lines = Self.parse(syncedLyrics)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.cachedKey == key else { return }
            if lines.isEmpty {
                self.state = .unavailable
            } else {
                self.cachedLines = lines
                self.state = .available(lines)
            }
        }
    }

    /// Parses `[mm:ss.xx] text` lines. Non-timestamp tags such as `[ar:...]`
    /// fail the Double parse and are skipped.
    static func parse(_ synced: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for raw in synced.components(separatedBy: .newlines) {
            guard let open = raw.firstIndex(of: "["),
                  let close = raw.firstIndex(of: "]"),
                  close > open else { continue }
            let stamp = String(raw[raw.index(after: open)..<close])
            let parts = stamp.split(separator: ":")
            guard parts.count == 2,
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else { continue }
            let text = String(raw[raw.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            lines.append(LyricLine(time: minutes * 60 + seconds, text: text))
        }
        return lines.sorted { $0.time < $1.time }
    }
}
