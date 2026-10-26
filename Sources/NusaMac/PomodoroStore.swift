import Combine
import Foundation

enum PomodoroPhase: String, Codable {
    case focus
    case rest
}

/// Pomodoro state machine: 25 minutes focus, 5 minutes rest, repeat.
/// The completed-cycle count is persisted per calendar day.
final class PomodoroStore: ObservableObject {
    static let focusDuration: TimeInterval = 25 * 60
    static let restDuration: TimeInterval = 5 * 60

    @Published private(set) var phase: PomodoroPhase = .focus
    @Published private(set) var secondsRemaining: TimeInterval = focusDuration
    @Published private(set) var isRunning = false
    @Published private(set) var completedCycles = 0

    private var timer: Timer?
    private let stateKey = "nusamac.pomodoro"

    private struct SavedState: Codable {
        let dayStart: Date
        let completedCycles: Int
    }

    init() {
        let today = Calendar.current.startOfDay(for: Date())
        if let saved = Persistence.load(SavedState.self, forKey: stateKey),
           Calendar.current.isDate(saved.dayStart, inSameDayAs: today) {
            completedCycles = saved.completedCycles
        }
    }

    func startPause() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        phase = .focus
        secondsRemaining = Self.focusDuration
    }

    var timeText: String {
        let total = max(0, Int(secondsRemaining))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: - Private

    private func tick() {
        if secondsRemaining > 1 {
            secondsRemaining -= 1
        } else {
            secondsRemaining = 0
            finishPhase()
        }
    }

    private func finishPhase() {
        pause()
        if phase == .focus {
            completedCycles += 1
            save()
            phase = .rest
            secondsRemaining = Self.restDuration
            Notifier.post(title: "Waktunya istirahat", body: "Sesi fokus selesai. Istirahat 5 menit.")
        } else {
            phase = .focus
            secondsRemaining = Self.focusDuration
            Notifier.post(title: "Kembali fokus", body: "Istirahat selesai. Mulai sesi fokus berikutnya.")
        }
    }

    private func save() {
        let state = SavedState(
            dayStart: Calendar.current.startOfDay(for: Date()),
            completedCycles: completedCycles
        )
        Persistence.save(state, forKey: stateKey)
    }
}
