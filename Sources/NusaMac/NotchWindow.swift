import AppKit
import Combine
import SwiftUI

/// The floating notch window: borderless, non-opaque, with a shadow, on top
/// of normal windows, present on every Space. It must be able to become key
/// so the SwiftUI buttons inside it receive clicks.
final class NotchWindow: NSWindow {
    var onHoverChange: ((Bool) -> Void)?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: NotchController.collapsedSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { true }

    /// True on MacBooks with a camera notch: the screen's safe-area top
    /// inset is only non-zero there. (safeAreaInsets lives on NSScreen /
    /// NSView, not on NSWindow.)
    var hasNotch: Bool {
        (screen ?? NSScreen.main)?.safeAreaInsets.top ?? 0 > 0
    }

    func installTracking() {
        guard let contentView = contentView else { return }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }
}

/// NSHostingView subclass that accepts the first mouse click, so a click on
/// the collapsed pill reaches the SwiftUI button without a wasted
/// activation-only click. (Whether SwiftUI's internal hit view honors this
/// is flagged for real-Mac verification in BUILD-NOTES.md.)
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Owns the notch window's geometry and expanded/collapsed state.
final class NotchController: ObservableObject {
    enum NotchTab: String, CaseIterable {
        case music = "Musik"
        case lyrics = "Lirik"
        case focus = "Fokus"
        case water = "Air"
        case shelf = "Rak"
        case todos = "Tugas"
    }

    static let collapsedSize = NSSize(width: 260, height: 32)
    static let expandedSize = NSSize(width: 380, height: 320)

    @Published private(set) var isExpanded = false
    @Published private(set) var isPinned = false
    @Published var selectedTab: NotchTab = .music
    @Published private(set) var hasNotch = false
    @Published private(set) var collapsedHeight: CGFloat = 32

    weak var window: NotchWindow?

    /// Hover expands; moving away collapses again unless pinned by click.
    func setHovered(_ hovered: Bool) {
        if hovered {
            setExpanded(true)
        } else if !isPinned {
            setExpanded(false)
        }
    }

    func togglePinned() {
        isPinned.toggle()
        setExpanded(isPinned)
    }

    func closeExpanded() {
        isPinned = false
        setExpanded(false)
    }

    /// Top-centre of the screen. On a notched Mac the collapsed pill grows
    /// to the notch height so it sits flush in the notch area.
    func reposition() {
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        let notchTop = screen.safeAreaInsets.top
        hasNotch = notchTop > 0
        if hasNotch {
            collapsedHeight = max(Self.collapsedSize.height, notchTop)
        }
        window.setFrame(frame(forExpanded: isExpanded, on: screen), display: true)
    }

    // MARK: - Private

    private func frame(forExpanded expanded: Bool, on screen: NSScreen) -> NSRect {
        let width = expanded ? Self.expandedSize.width : Self.collapsedSize.width
        let height = expanded ? Self.expandedSize.height : collapsedHeight
        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    private func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            window.animator().setFrame(frame(forExpanded: expanded, on: screen), display: true)
        }
    }
}
