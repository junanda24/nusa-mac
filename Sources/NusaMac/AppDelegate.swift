import AppKit
import SwiftUI

/// App entry point. There is intentionally no main.swift: this class carries
/// @main and boots NSApplication manually.
///
/// NSApplication's `delegate` property does not retain, so the delegate is
/// held in `retainedDelegate` for the lifetime of the process.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var retainedDelegate: AppDelegate?

    private var notchWindow: NotchWindow?
    private var notchController: NotchController?
    private var statusBar: StatusBarController?

    private let nowPlaying = NowPlayingService()
    private let lyrics = LyricsService()
    private let pomodoro = PomodoroStore()
    private let water = WaterStore()
    private let shelf = ShelfStore()
    private let todos = TodoStore()
    private let system = SystemStatus()

    private var waterReminderTimer: Timer?
    private var screenChangeObserver: NSObjectProtocol?

    static func main() {
        let delegate = AppDelegate()
        retainedDelegate = delegate
        let app = NSApplication.shared
        app.delegate = delegate
        _ = app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.requestAuthorization()

        let controller = NotchController()
        let window = NotchWindow()
        controller.window = window
        window.onHoverChange = { [weak controller] hovered in
            controller?.setHovered(hovered)
        }

        let content = ContentView()
            .environmentObject(controller)
            .environmentObject(nowPlaying)
            .environmentObject(lyrics)
            .environmentObject(pomodoro)
            .environmentObject(water)
            .environmentObject(shelf)
            .environmentObject(todos)
            .environmentObject(system)
        window.contentView = ClickThroughHostingView(rootView: content)
        window.installTracking()

        nowPlaying.onTrackChange = { [weak self] track in
            self?.lyrics.fetch(for: track)
        }
        nowPlaying.start()
        system.start()

        window.orderFront(nil)
        controller.reposition()

        notchController = controller
        notchWindow = window
        statusBar = StatusBarController(notchWindow: window, notchController: controller)

        waterReminderTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.water.maybeRemind()
        }
        water.maybeRemind()

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak controller] _ in
            controller?.reposition()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        waterReminderTimer?.invalidate()
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
