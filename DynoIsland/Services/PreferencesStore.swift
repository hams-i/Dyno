import AppKit
import Foundation
import ServiceManagement

enum SettingsAppearance: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.appearanceSystem
        case .light: L10n.appearanceLight
        case .dark: L10n.appearanceDark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var languageCode: String
    var launchAtLogin: Bool
    var appearance: SettingsAppearance

    static let `default` = AppPreferences(
        languageCode: "tr",
        launchAtLogin: false,
        appearance: .system
    )

    enum CodingKeys: String, CodingKey {
        case languageCode, launchAtLogin, appearance
    }

    init(languageCode: String, launchAtLogin: Bool, appearance: SettingsAppearance) {
        self.languageCode = languageCode
        self.launchAtLogin = launchAtLogin
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode) ?? "tr"
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        appearance = try container.decodeIfPresent(SettingsAppearance.self, forKey: .appearance) ?? .system
    }
}

@MainActor
final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    @Published private(set) var preferences: AppPreferences

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        DynoDataStore.rootDirectory.appendingPathComponent("preferences.json")
    }

    private init() {
        let url = DynoDataStore.rootDirectory.appendingPathComponent("preferences.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode(AppPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .default
        }
        L10n.cachedIsTurkish = preferences.languageCode != "en"
        syncLaunchAtLoginFromSystem()
    }

    var isTurkish: Bool { preferences.languageCode != "en" }

    func setLanguageCode(_ code: String) {
        preferences.languageCode = (code == "en") ? "en" : "tr"
        L10n.cachedIsTurkish = preferences.languageCode != "en"
        save()
        objectWillChange.send()
        NotificationCenter.default.post(name: .dynoLanguageDidChange, object: nil)
    }

    func setAppearance(_ appearance: SettingsAppearance) {
        preferences.appearance = appearance
        save()
        NotificationCenter.default.post(name: .dynoAppearanceDidChange, object: nil)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        preferences.launchAtLogin = enabled
        save()
        applyLaunchAtLogin(enabled)
    }

    func refreshLaunchAtLoginStatus() {
        syncLaunchAtLoginFromSystem()
    }

    private func syncLaunchAtLoginFromSystem() {
        let status = SMAppService.mainApp.status
        let enabled = status == .enabled
        if preferences.launchAtLogin != enabled {
            preferences.launchAtLogin = enabled
            save()
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            syncLaunchAtLoginFromSystem()
        }
    }

    private func save() {
        guard let data = try? encoder.encode(preferences) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

extension Notification.Name {
    static let dynoLanguageDidChange = Notification.Name("dynoLanguageDidChange")
    static let dynoAppearanceDidChange = Notification.Name("dynoAppearanceDidChange")
}
