import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private weak var model: AppModel?
    private var languageObserver: NSObjectProtocol?
    private var appearanceObserver: NSObjectProtocol?

    func show(model: AppModel) {
        self.model = model
        installObserversIfNeeded()

        if let window, window.isVisible {
            applyAppearance(to: window)
            window.title = L10n.settingsTitle
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = SettingsRootView(model: model)
            .environmentObject(PreferencesStore.shared)

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.settingsTitle
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .preference
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 740, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        applyAppearance(to: window)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func installObserversIfNeeded() {
        if languageObserver == nil {
            languageObserver = NotificationCenter.default.addObserver(
                forName: .dynoLanguageDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.window?.title = L10n.settingsTitle
                }
            }
        }
        if appearanceObserver == nil {
            appearanceObserver = NotificationCenter.default.addObserver(
                forName: .dynoAppearanceDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    if let window = self?.window {
                        self?.applyAppearance(to: window)
                    }
                }
            }
        }
    }

    private func applyAppearance(to window: NSWindow) {
        window.appearance = PreferencesStore.shared.preferences.appearance.nsAppearance
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case info
    case preferences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .info: L10n.aboutPane
        case .preferences: L10n.preferencesPane
        }
    }

    var symbol: String {
        switch self {
        case .info: return "info.circle"
        case .preferences: return "slider.horizontal.3"
        }
    }
}

struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var prefs: PreferencesStore
    @State private var pane: SettingsPane = .info

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 188)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            Group {
                switch pane {
                case .info:
                    InfoSettingsPane()
                case .preferences:
                    PreferencesSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        }
        .frame(minWidth: 700, minHeight: 520)
        // Dil değişince tüm metinler yenilensin.
        .id(prefs.preferences.languageCode)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.settingsTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(SettingsPane.allCases) { item in
                Button {
                    pane = item
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 16)
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(pane == item ? Color.accentColor : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        if pane == item {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct InfoSettingsPane: View {
    @EnvironmentObject private var prefs: PreferencesStore

    private let repoURL = URL(string: "https://github.com/hams-i/Dyno")!
    private var turkish: Bool { prefs.isTurkish }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Dyno Island")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text(
                        turkish
                            ? "Mac çentiğinde yaşayan modern yardımcı"
                            : "A modern companion that lives in the Mac notch"
                    )
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    Text(turkish ? "Sürüm \(version)" : "Version \(version)")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            Text(
                turkish
                    ? "Dyno Island; şimdi çalıyor, pano geçmişi, görevler, timer ve sayaç özelliklerini Dynamic Island benzeri bir panelde birleştirir. İşaretçi çentiğin üzerindeyken genişler, istediğinizde sabitlenir veya adaya küçülür."
                    : "Dyno Island brings Now Playing, clipboard history, tasks, a timer, and a counter into a Dynamic Island–style panel. It expands when you hover the notch, pins when you want it to stay, and collapses back into the island."
            )
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                featureChip(
                    symbol: "waveform",
                    title: L10n.tabNowPlaying,
                    detail: turkish ? "Kapak, kontroller, zaman çizelgesi" : "Artwork, controls, timeline"
                )
                featureChip(
                    symbol: "doc.on.clipboard",
                    title: L10n.tabClipboard,
                    detail: turkish ? "Kalıcı geçmiş, adaya sabitlenebilir" : "Persistent history, dockable"
                )
                featureChip(
                    symbol: "checklist",
                    title: L10n.tabTasks,
                    detail: turkish ? "Todo listesi, filtreler" : "Todo list with filters"
                )
                featureChip(
                    symbol: "timer",
                    title: L10n.tabTimer,
                    detail: turkish ? "Adaya sabitlenebilir" : "Dockable to the island"
                )
                featureChip(
                    symbol: "plus.circle",
                    title: L10n.tabCounter,
                    detail: turkish ? "Tek dokunuşla +1" : "One-tap increment"
                )
            }

            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(turkish ? "Açık kaynak" : "Open source")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text(
                        turkish
                            ? "Dyno Island açık kaynaklı bir projedir. Kaynak kodu incelemek, katkıda bulunmak veya sorun bildirmek için GitHub deposunu ziyaret edin."
                            : "Dyno Island is an open-source project. Visit the GitHub repository to explore the code, contribute, or report issues."
                    )
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Link(destination: repoURL) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 11, weight: .semibold))
                            Text("github.com/hams-i/Dyno")
                                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func featureChip(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct PreferencesSettingsPane: View {
    @EnvironmentObject private var prefs: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.preferencesPane)
                .font(.system(size: 20, weight: .semibold))

            settingsCard {
                HStack {
                    Text(L10n.language)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("", selection: languageBinding) {
                        Text("Türkçe").tag("tr")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                Divider().padding(.vertical, 4)

                HStack {
                    Text(L10n.appearance)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("", selection: appearanceBinding) {
                        ForEach(SettingsAppearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                }

                Divider().padding(.vertical, 4)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.launchAtLogin)
                            .font(.system(size: 13, weight: .medium))
                        Text(L10n.launchAtLoginHint)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: launchBinding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            prefs.refreshLaunchAtLoginStatus()
        }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { prefs.preferences.languageCode },
            set: { prefs.setLanguageCode($0) }
        )
    }

    private var appearanceBinding: Binding<SettingsAppearance> {
        Binding(
            get: { prefs.preferences.appearance },
            set: { prefs.setAppearance($0) }
        )
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { prefs.preferences.launchAtLogin },
            set: { prefs.setLaunchAtLogin($0) }
        )
    }
}

private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    )
    .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    }
}
