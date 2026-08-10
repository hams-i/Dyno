import Foundation

@MainActor
final class TimerService: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isRunning = false

    private var tickTimer: Timer?
    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private let store = ActivitiesStore.shared

    var displayString: String {
        Self.format(elapsed)
    }

    init() {
        restore()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startedAt = Date()
        startTicking()
        persist()
    }

    func stop() {
        guard isRunning else { return }
        accumulated = currentElapsed()
        elapsed = accumulated
        isRunning = false
        startedAt = nil
        stopTicking()
        persist()
    }

    func toggle() {
        if isRunning { stop() } else { start() }
    }

    func reset() {
        stopTicking()
        isRunning = false
        startedAt = nil
        accumulated = 0
        elapsed = 0
        persist()
    }

    private func restore() {
        let saved = store.state
        accumulated = max(0, saved.timerAccumulated)
        if saved.timerIsRunning, let started = saved.timerStartedAt {
            startedAt = started
            isRunning = true
            elapsed = currentElapsed()
            startTicking()
        } else {
            isRunning = false
            startedAt = nil
            elapsed = accumulated
        }
    }

    private func persist() {
        store.update { state in
            state.timerAccumulated = isRunning ? currentElapsed() : accumulated
            state.timerIsRunning = isRunning
            state.timerStartedAt = startedAt
        }
    }

    private func startTicking() {
        stopTicking()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        elapsed = currentElapsed()
        // Ara sıra diske yaz — yeniden başlatmada kayıp olmasın.
        if Int(elapsed * 10) % 20 == 0 {
            persist()
        }
    }

    private func currentElapsed() -> TimeInterval {
        guard let startedAt else { return accumulated }
        return accumulated + Date().timeIntervalSince(startedAt)
    }

    static func format(_ value: TimeInterval) -> String {
        let totalCentiseconds = Int((value * 100).rounded(.down))
        let minutes = totalCentiseconds / 6_000
        let seconds = (totalCentiseconds % 6_000) / 100
        let centiseconds = totalCentiseconds % 100
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d.%02d", hours, mins, seconds, centiseconds)
        }
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
}
