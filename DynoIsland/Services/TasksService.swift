import Foundation

@MainActor
final class TasksService: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var filter: TasksFilter = .all
    /// Dinamik adada gösterilen / satır tıklamasıyla seçilen görev.
    @Published private(set) var selectedTaskID: UUID?

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let selectionKey = "com.dynoisland.tasks.selectedID"

    init() {
        tasks = load()
        if let raw = UserDefaults.standard.string(forKey: selectionKey),
           let id = UUID(uuidString: raw),
           tasks.contains(where: { $0.id == id }) {
            selectedTaskID = id
        } else {
            selectedTaskID = tasks.first(where: { !$0.isCompleted })?.id ?? tasks.first?.id
            persistSelection()
        }
    }

    var filteredTasks: [TaskItem] {
        switch filter {
        case .all:
            return tasks
        case .active:
            return tasks.filter { !$0.isCompleted }
        case .completed:
            return tasks.filter(\.isCompleted)
        }
    }

    var activeCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    var selectedTask: TaskItem? {
        guard let selectedTaskID else { return nil }
        return tasks.first { $0.id == selectedTaskID }
    }

    /// Ada sol metni — seçili görevin ilk 8 harfi (sağa doğru fade ile çizilir).
    var islandLabel: String {
        guard let task = selectedTask else { return "—" }
        let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "—" }
        return String(title.prefix(8))
    }

    var canCompleteSelected: Bool {
        guard let task = selectedTask else { return false }
        return !task.isCompleted
    }

    func select(_ id: UUID) {
        guard tasks.contains(where: { $0.id == id }) else { return }
        guard selectedTaskID != id else { return }
        selectedTaskID = id
        persistSelection()
    }

    @discardableResult
    func add(_ rawTitle: String) -> Bool {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        let item = TaskItem(title: title)
        tasks.insert(item, at: 0)
        selectedTaskID = item.id
        persist()
        persistSelection()
        return true
    }

    func toggle(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isCompleted.toggle()
        if tasks[index].isCompleted {
            tasks[index].completedAt = Date()
        } else {
            tasks[index].completedAt = nil
        }
        persist()
    }

    private var lastCompleteUptime: TimeInterval = 0

    /// Ada üzerindeki tik: seçili görevi tamamlar, alttaki (tamamlanmamış) maddeyi seçer.
    @discardableResult
    func completeSelected() -> Bool {
        // AppKit + SwiftUI aynı tıklamada iki kez tetiklenmesin.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastCompleteUptime > 0.28 else { return false }

        // Seçili tamamlanmışsa / yoksa ilk tamamlanmamışa geç.
        let targetID: UUID
        if let id = selectedTaskID,
           let task = tasks.first(where: { $0.id == id }),
           !task.isCompleted {
            targetID = id
        } else if let id = tasks.first(where: { !$0.isCompleted })?.id {
            targetID = id
        } else {
            return false
        }

        guard let index = tasks.firstIndex(where: { $0.id == targetID }) else { return false }

        lastCompleteUptime = now
        tasks[index].isCompleted = true
        tasks[index].completedAt = Date()

        // Bir altındaki ilk tamamlanmamış; yoksa listedeki başka aktif.
        let below = tasks.indices.contains(index + 1)
            ? tasks[(index + 1)...].first(where: { !$0.isCompleted })
            : nil
        if let below {
            selectedTaskID = below.id
        } else if let other = tasks.first(where: { !$0.isCompleted }) {
            selectedTaskID = other.id
        } else {
            selectedTaskID = targetID
        }

        persist()
        persistSelection()
        return true
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        if selectedTaskID == id {
            selectedTaskID = tasks.first(where: { !$0.isCompleted })?.id ?? tasks.first?.id
            persistSelection()
        }
        persist()
    }

    func clearCompleted() {
        let removingSelected = selectedTask.map(\.isCompleted) == true
        tasks.removeAll { $0.isCompleted }
        if removingSelected {
            selectedTaskID = tasks.first(where: { !$0.isCompleted })?.id ?? tasks.first?.id
            persistSelection()
        }
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: DynoDataStore.tasksURL, options: .atomic)
    }

    private func persistSelection() {
        if let selectedTaskID {
            UserDefaults.standard.set(selectedTaskID.uuidString, forKey: selectionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectionKey)
        }
    }

    private func load() -> [TaskItem] {
        guard let data = try? Data(contentsOf: DynoDataStore.tasksURL),
              let decoded = try? decoder.decode([TaskItem].self, from: data) else {
            return []
        }
        return decoded
    }
}
