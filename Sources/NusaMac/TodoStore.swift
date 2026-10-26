import Combine
import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    let createdAt: Date

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.createdAt = Date()
    }
}

/// Plain persisted to-do list: add, complete, delete. No cloud, no account.
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let stateKey = "nusamac.todos"

    init() {
        items = Persistence.load([TodoItem].self, forKey: stateKey) ?? []
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isDone.toggle()
        save()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    private func save() {
        Persistence.save(items, forKey: stateKey)
    }
}
