import AppKit
import Combine
import Foundation

struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    let path: String
    let addedAt: Date

    var name: String { URL(fileURLWithPath: path).lastPathComponent }
    var url: URL { URL(fileURLWithPath: path) }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }

    init(path: String) {
        self.id = UUID()
        self.path = path
        self.addedAt = Date()
    }
}

/// File shelf: stores file *paths*, never copies. The app is unsandboxed
/// (no entitlements file), so stored paths stay directly openable.
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    private let stateKey = "nusamac.shelf"

    init() {
        items = Persistence.load([ShelfItem].self, forKey: stateKey) ?? []
    }

    func add(paths: [String]) {
        for path in paths where !items.contains(where: { $0.path == path }) {
            items.append(ShelfItem(path: path))
        }
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func reveal(_ item: ShelfItem) {
        guard item.exists else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private func save() {
        Persistence.save(items, forKey: stateKey)
    }
}
