import Foundation

@MainActor
final class CounterService: ObservableObject {
    @Published private(set) var count: Int
    @Published private(set) var note: String
    /// `true` → sayı aşağı kayar (−), `false` → yukarı (+).
    @Published private(set) var countsDown = false

    private let store = ActivitiesStore.shared

    init() {
        count = max(0, store.state.counter)
        note = store.state.counterNote
    }

    func increment() {
        countsDown = false
        count += 1
        persist()
    }

    func decrement() {
        guard count > 0 else { return }
        countsDown = true
        count -= 1
        persist()
    }

    func reset() {
        guard count != 0 else { return }
        countsDown = true
        count = 0
        persist()
    }

    func updateNote(_ text: String) {
        note = text
        persist()
    }

    private func persist() {
        store.update {
            $0.counter = count
            $0.counterNote = note
        }
    }
}
