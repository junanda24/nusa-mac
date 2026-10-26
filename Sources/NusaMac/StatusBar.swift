import AppKit
import ServiceManagement

/// Menu-bar item (the app has no Dock icon — LSUIElement is set in
/// Info.plist). Menu: show/hide the notch, launch-at-login toggle, quit.
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var notchWindow: NotchWindow?
    private weak var notchController: NotchController?
    private var loginItem: NSMenuItem?

    init(notchWindow: NotchWindow, notchController: NotchController) {
        self.notchWindow = notchWindow
        self.notchController = notchController
        super.init()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "NusaMac"

        let menu = NSMenu()
        let toggleItem = NSMenuItem(
            title: "Tampilkan/Sembunyikan Notch",
            action: #selector(toggleNotch),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let login = NSMenuItem(
            title: "Jalankan saat login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        loginItem = login

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Keluar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleNotch() {
        guard let window = notchWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
            notchController?.reposition()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Best-effort only: under `swift run` (no bundle) registration
            // fails, and the menu simply keeps reflecting the real status.
        }
        loginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
