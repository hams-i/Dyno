import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, createdAt, completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        if isCompleted, completedAt == nil {
            completedAt = createdAt
        }
    }
}

enum TasksFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.tasksFilterAll
        case .active: L10n.tasksFilterActive
        case .completed: L10n.tasksFilterCompleted
        }
    }
}
