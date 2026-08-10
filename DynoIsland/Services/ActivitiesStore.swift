import Foundation

/// `~/Library/Application Support/DynoIsland/` — kod değişse de veriler burada kalır.
enum DynoDataStore {
    static var rootDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let folder = base.appendingPathComponent("DynoIsland", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static var activitiesURL: URL {
        rootDirectory.appendingPathComponent("activities.json")
    }

    static var clipboardURL: URL {
        rootDirectory.appendingPathComponent("clipboard-history.json")
    }
}

struct PersistedActivities: Codable, Equatable {
    var counter: Int
    var counterNote: String
    var timerAccumulated: TimeInterval
    var timerIsRunning: Bool
    /// Çalışıyorsa duvar saati başlangıcı — yeniden açılınca süre devam eder.
    var timerStartedAt: Date?

    static let empty = PersistedActivities(
        counter: 0,
        counterNote: "",
        timerAccumulated: 0,
        timerIsRunning: false,
        timerStartedAt: nil
    )

    enum CodingKeys: String, CodingKey {
        case counter, counterNote, timerAccumulated, timerIsRunning, timerStartedAt
    }

    init(
        counter: Int,
        counterNote: String,
        timerAccumulated: TimeInterval,
        timerIsRunning: Bool,
        timerStartedAt: Date?
    ) {
        self.counter = counter
        self.counterNote = counterNote
        self.timerAccumulated = timerAccumulated
        self.timerIsRunning = timerIsRunning
        self.timerStartedAt = timerStartedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        counter = try container.decode(Int.self, forKey: .counter)
        counterNote = try container.decodeIfPresent(String.self, forKey: .counterNote) ?? ""
        timerAccumulated = try container.decode(TimeInterval.self, forKey: .timerAccumulated)
        timerIsRunning = try container.decode(Bool.self, forKey: .timerIsRunning)
        timerStartedAt = try container.decodeIfPresent(Date.self, forKey: .timerStartedAt)
    }
}

@MainActor
final class ActivitiesStore {
    static let shared = ActivitiesStore()

    private(set) var state: PersistedActivities
    private let legacyCounterKey = "com.dynoisland.counter.count"
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        state = Self.load(from: DynoDataStore.activitiesURL, decoder: decoder) ?? .empty

        if state == .empty {
            let legacy = UserDefaults.standard.integer(forKey: legacyCounterKey)
            if legacy > 0 {
                state.counter = legacy
                save()
                UserDefaults.standard.removeObject(forKey: legacyCounterKey)
            }
        }
    }

    func update(_ mutate: (inout PersistedActivities) -> Void) {
        mutate(&state)
        save()
    }

    private func save() {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: DynoDataStore.activitiesURL, options: .atomic)
    }

    private static func load(from url: URL, decoder: JSONDecoder) -> PersistedActivities? {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode(PersistedActivities.self, from: data) else {
            return nil
        }
        return decoded
    }
}
