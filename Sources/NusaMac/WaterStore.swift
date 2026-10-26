import Combine
import Foundation

/// Daily water intake in glasses. Count resets each calendar day.
/// Reminders are hourly, only between 08:00 and 21:00, and only while the
/// daily goal is unmet.
final class WaterStore: ObservableObject {
    @Published private(set) var glassesToday = 0
    @Published private(set) var dailyGoal = 8

    private struct SavedState: Codable {
        let dayStart: Date
        let glasses: Int
        let goal: Int
        let lastReminder: Date?
    }

    private let stateKey = "nusamac.water"
    private var lastReminder: Date?

    init() {
        let today = Calendar.current.startOfDay(for: Date())
        if let saved = Persistence.load(SavedState.self, forKey: stateKey),
           Calendar.current.isDate(saved.dayStart, inSameDayAs: today) {
            glassesToday = saved.glasses
            dailyGoal = saved.goal
            lastReminder = saved.lastReminder
        }
    }

    func logGlass() {
        glassesToday += 1
        save()
    }

    func removeGlass() {
        guard glassesToday > 0 else { return }
        glassesToday -= 1
        save()
    }

    func setGoal(_ goal: Int) {
        dailyGoal = max(1, min(20, goal))
        save()
    }

    /// Called once a minute by the app delegate.
    func maybeRemind(now: Date = Date()) {
        guard glassesToday < dailyGoal else { return }
        let hour = Calendar.current.component(.hour, from: now)
        guard (8...21).contains(hour) else { return }
        if let last = lastReminder, now.timeIntervalSince(last) < 3600 { return }
        lastReminder = now
        save()
        Notifier.post(
            title: "Waktunya minum",
            body: "Kamu baru minum \(glassesToday) dari \(dailyGoal) gelas hari ini."
        )
    }

    // MARK: - Private

    private func save() {
        let state = SavedState(
            dayStart: Calendar.current.startOfDay(for: Date()),
            glasses: glassesToday,
            goal: dailyGoal,
            lastReminder: lastReminder
        )
        Persistence.save(state, forKey: stateKey)
    }
}
