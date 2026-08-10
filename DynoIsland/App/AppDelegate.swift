import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var panelController: IslandPanelController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Görsel regresyon kontrolleri için isteğe bağlı geliştirici başlangıç durumu.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--expanded") {
            model.forceExpandedForLaunch()
        }
        if arguments.contains("--clipboard") {
            model.selectedTab = .clipboard
        }

        let controller = IslandPanelController(model: model)
        panelController = controller
        controller.show()

        statusItemController = StatusItemController(model: model)

        model.startServices()

#if DEBUG
        if arguments.contains("--stress-window") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.runWindowStressTest(remainingTransitions: 24)
            }
        }
#endif

        if let snapshotArgument = arguments.first(where: { $0.hasPrefix("--snapshot=") }) {
            let path = String(snapshotArgument.dropFirst("--snapshot=".count))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                try? self?.panelController?.writeSnapshot(to: URL(fileURLWithPath: path))
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stopServices()
        NotchSpace.shared.tearDown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

#if DEBUG
    private func runWindowStressTest(remainingTransitions: Int) {
        guard remainingTransitions > 0 else {
            print("DYNO_WINDOW_STRESS_TEST_PASSED")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
            return
        }

        model.debugToggleExpanded()
        if model.isExpanded {
            model.selectedTab = model.selectedTab == .media ? .clipboard : .media
        }
        // Pencere animasyonu + içerik gecikmesinin bitmesini bekle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.runWindowStressTest(remainingTransitions: remainingTransitions - 1)
        }
    }
#endif
}
