import AppKit
import Combine
import Foundation

/// One snapshot of whatever is currently playing in Music or Spotify.
struct Track: Equatable {
    enum PlayerApp: String {
        case music = "Music"
        case spotify = "Spotify"
    }

    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let position: TimeInterval
    let isPlaying: Bool
    let player: PlayerApp

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    /// Cache key for lyrics: a track change is a title/artist/album change.
    var cacheKey: String { "\(title)|\(artist)|\(album)" }
}

/// Now Playing via AppleScript only — no private APIs, no ScriptingBridge.
///
/// Safety rules:
/// - We never `tell` an app that is not running. Addressing a non-running app
///   would launch it, so we first check NSWorkspace.runningApplications.
/// - If the user denies the Automation permission, executeAndReturnError
///   returns an error and we simply report "no track". Never a modal, never
///   a crash.
/// - Polling is light (every 2 s); the progress bar advances locally between
///   polls so it still looks alive.
final class NowPlayingService: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var activePlayer: Track.PlayerApp?

    /// Fired only when the track itself changes (not on position updates),
    /// so the lyrics service does not refetch every poll.
    var onTrackChange: ((Track?) -> Void)?

    private var pollTimer: Timer?
    private var tickTimer: Timer?

    func start() {
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.advanceLocalPosition()
        }
    }

    func togglePlayPause() {
        guard let player = track?.player ?? activePlayer else { return }
        _ = runAppleScript("tell application \"\(player.rawValue)\" to playpause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }

    func nextTrack() {
        guard let player = track?.player ?? activePlayer else { return }
        _ = runAppleScript("tell application \"\(player.rawValue)\" to next track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }

    // MARK: - Private

    private func advanceLocalPosition() {
        guard let current = track, current.isPlaying else { return }
        track = Track(
            title: current.title,
            artist: current.artist,
            album: current.album,
            duration: current.duration,
            position: min(current.position + 0.5, current.duration),
            isPlaying: true,
            player: current.player
        )
    }

    private func refresh() {
        let runningIDs = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
        var found: Track?
        if runningIDs.contains("com.apple.Music"), let musicTrack = query(.music) {
            found = musicTrack
            if musicTrack.isPlaying {
                apply(musicTrack)
                return
            }
        }
        if runningIDs.contains("com.spotify.client"), let spotifyTrack = query(.spotify) {
            if found == nil || spotifyTrack.isPlaying {
                found = spotifyTrack
            }
        }
        apply(found)
    }

    private func apply(_ newTrack: Track?) {
        let oldKey = track?.cacheKey
        track = newTrack
        activePlayer = newTrack?.player
        if newTrack?.cacheKey != oldKey {
            onTrackChange?(newTrack)
        }
    }

    /// Queries one player. Returns nil when the player has no current track,
    /// is stopped, or the Automation permission was denied.
    private func query(_ player: Track.PlayerApp) -> Track? {
        // NOTE: AppleScript has no "\n" escape inside string literals, so
        // fields are joined with `return` (the newline constant).
        let source = """
        tell application "\(player.rawValue)"
            set tTitle to name of current track
            set tArtist to artist of current track
            set tAlbum to album of current track
            set tDuration to duration of current track
            set tPosition to player position
            set tState to player state as string
            return tTitle & return & tArtist & return & tAlbum & return & tDuration & return & tPosition & return & tState
        end tell
        """
        guard let output = runAppleScript(source) else { return nil }
        let fields = output.components(separatedBy: "\n")
        guard fields.count == 6 else { return nil }
        let state = fields[5].trimmingCharacters(in: .whitespacesAndNewlines)
        guard state != "stopped" else { return nil }
        guard let rawDuration = Double(fields[3]),
              let position = Double(fields[4]) else { return nil }
        // Music reports duration in seconds; Spotify reports milliseconds.
        let duration = player == .spotify ? rawDuration / 1000.0 : rawDuration
        guard duration > 0 else { return nil }
        return Track(
            title: fields[0],
            artist: fields[1],
            album: fields[2],
            duration: duration,
            position: position,
            isPlaying: state == "playing",
            player: player
        )
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if errorInfo != nil { return nil }
        return descriptor.stringValue
    }
}
