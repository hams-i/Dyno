import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private var statusItem: NSStatusItem?
    private var prefsObserver: NSObjectProtocol?

    init(model: AppModel) {
        self.model = model
        super.init()
        install()
        prefsObserver = NotificationCenter.default.addObserver(
            forName: .dynoLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildMenu()
            }
        }
    }

    deinit {
        if let prefsObserver {
            NotificationCenter.default.removeObserver(prefsObserver)
        }
    }

    private func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(named: "MenuAstroid")
            image?.isTemplate = true
            button.image = image
            button.image?.size = NSSize(width: 16, height: 16)
            button.toolTip = "Dyno Island"
        }
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "Dyno Island", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: L10n.toggleIsland,
            action: #selector(toggleIsland),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.image = NSImage(systemSymbolName: "rectangle.inset.filled", accessibilityDescription: nil)
        toggleItem.image?.isTemplate = true
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let pinItem = NSMenuItem(
            title: pinTitle,
            action: #selector(togglePin),
            keyEquivalent: ""
        )
        pinItem.target = self
        pinItem.image = NSImage(
            systemSymbolName: model.isPinned ? "pin.slash" : "pin.fill",
            accessibilityDescription: pinTitle
        )
        pinItem.image?.isTemplate = true
        menu.addItem(pinItem)

        let settingsItem = NSMenuItem(
            title: L10n.settings + "…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: nil
        )
        settingsItem.image?.isTemplate = true
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.quit,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = NSImage(
            systemSymbolName: "power",
            accessibilityDescription: nil
        )
        quitItem.image?.isTemplate = true
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private var pinTitle: String {
        model.isPinned ? L10n.unpin : L10n.pin
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items where item.action == #selector(togglePin) {
            item.title = pinTitle
            item.image = NSImage(
                systemSymbolName: model.isPinned ? "pin.slash" : "pin.fill",
                accessibilityDescription: pinTitle
            )
            item.image?.isTemplate = true
        }
    }

    @objc private func toggleIsland() {
        model.toggleIslandFromHotKey()
    }

    @objc private func togglePin() {
        model.togglePin()
    }

    @objc private func openSettings() {
        model.openSettings()
    }

    @objc private func quit() {
        model.quit()
    }
}
