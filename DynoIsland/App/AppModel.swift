import AppKit
import SwiftUI

enum IslandTab: String, CaseIterable, Identifiable {
    case media
    case clipboard
    case timer
    case counter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: L10n.tabNowPlaying
        case .clipboard: L10n.tabClipboard
        case .timer: L10n.tabTimer
        case .counter: L10n.tabCounter
        }
    }

    var symbol: String {
        switch self {
        case .media: "waveform"
        case .clipboard: "doc.on.clipboard"
        case .timer: "timer"
        case .counter: "plus.circle"
        }
    }

    var canDockToIsland: Bool {
        self == .timer || self == .counter
    }
}

@MainActor
final class AppModel: ObservableObject {
    /// Pencere hedef boyutu (panel controller bunu izler).
    @Published private(set) var isExpanded = false
    /// Geniş içerik hedefte mi — içeriğin görünürlüğü `morphProgress` ile
    /// sürekli değişir, bu bayrak yalnızca hedef durumu bildirir.
    @Published private(set) var showsExpandedContent = false
    /// Yukarı ok ile kilitlendi: hover kapalı, yalnızca aşağı ok ile açılır.
    @Published private(set) var isActivityDocked = false
    /// Açılış animasyonu 0…1 — ada çentikten yanlara doğru açılır.
    @Published var launchReveal: CGFloat = 0
    /// Pencere ilerlemesi 0…1 (0 = ada, 1 = geniş panel). Panel controller her
    /// karede pencere boyutuyla aynı anda günceller; öğe uçuşu buna kilitli.
    @Published var morphProgress: CGFloat = 0
    /// Geniş yerleşimdeki hedef konum/boyutlar. Bilinçli olarak @Published
    /// değil — ölçüm her karede yeniden çizim tetiklemesin diye.
    var morphTargets: [MorphAnchor: MorphTarget] = [:]
    /// Daraltılmış panel boyutu — ada uçlarının referansı.
    @Published var collapsedPanelSize: CGSize = CGSize(width: 300, height: 33)
    /// Sekme sayfalarının yatay kayması. Morph öğeleri de bunu izler, böylece
    /// kendi sayfalarıyla birlikte kayarlar.
    @Published var pageScroll: CGFloat = 0
    @Published var pageWidth: CGFloat = 1

    func restScroll(for tab: IslandTab) -> CGFloat {
        -CGFloat(tab.pageIndex) * pageWidth
    }
    @Published var isPinned = false
    @Published var selectedTab: IslandTab = .media {
        didSet {
            if !selectedTab.canDockToIsland, isActivityDocked {
                isActivityDocked = false
            }
            refreshIslandSideExtra()
        }
    }

    /// Menü çubuğu / çentik yüksekliği — genişleyince üst kısayollar bunun altında durur.
    @Published var menuBarHeight: CGFloat = 32
    /// Daraltılmış adanın alt köşe yarıçapı (donanım çentiğiyle aynı).
    @Published var islandCornerRadius: CGFloat = 10

    var expandedPanelSize: CGSize {
        CGSize(width: 600, height: 268)
    }

    /// Ada kanatları çentiğin iki yanına düşer: içerik bu genişliği aşarsa
    /// çentiğin altında kalıp görünmez olur. Öğeler ada boyutundayken
    /// kendilerini ölçüp gereken kanat genişliğini bildirir, ada da ona göre
    /// animasyonlu genişler.
    static let islandBaseSideExtra: CGFloat = 112

    @Published private(set) var islandSideExtra: CGFloat = AppModel.islandBaseSideExtra
    private var islandLeadingHalfWidths: [IslandTab: CGFloat] = [:]

    func reportIslandLeadingHalfWidth(_ width: CGFloat, for tab: IslandTab) {
        guard width > 0 else { return }
        if let existing = islandLeadingHalfWidths[tab], abs(existing - width) < 0.5 { return }
        islandLeadingHalfWidths[tab] = width
        refreshIslandSideExtra()
    }

    private func refreshIslandSideExtra() {
        let needed = (islandLeadingHalfWidths[selectedTab] ?? 0) * 2
        let value = max(Self.islandBaseSideExtra, needed.rounded(.up))
        guard abs(value - islandSideExtra) > 0.5 else { return }
        islandSideExtra = value
    }

    let nowPlaying = NowPlayingService()
    let clipboard = ClipboardHistoryService()
    let timer = TimerService()
    let counter = CounterService()
    let preferences = PreferencesStore.shared

    private var hoverExpansion: DispatchWorkItem?
    private var hoverCollapse: DispatchWorkItem?
    private var isPointerInside = false

    func startServices() {
        nowPlaying.start()
        clipboard.start()
    }

    func stopServices() {
        hoverExpansion?.cancel()
        hoverCollapse?.cancel()
        nowPlaying.stop()
        clipboard.stop()
        timer.stop()
    }

    func hoverChanged(isInside: Bool) {
        guard isPointerInside != isInside else { return }
        isPointerInside = isInside

        hoverExpansion?.cancel()
        hoverCollapse?.cancel()
        hoverExpansion = nil
        hoverCollapse = nil

        // Yukarı ok ile dock: hover ile açılma/kapanma yok — yalnızca aşağı ok.
        guard !isActivityDocked else { return }

        if isInside {
            guard !isExpanded else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isPointerInside, !self.isExpanded, !self.isActivityDocked else { return }
                self.setExpanded(true)
            }
            hoverExpansion = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
        } else {
            guard isExpanded, !isPinned else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self,
                      !self.isPointerInside,
                      !self.isPinned,
                      !self.isActivityDocked else { return }
                // Doğal küçülme: dock değil — hover tekrar çalışır, aşağı ok yok.
                self.setExpanded(false)
            }
            hoverCollapse = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }
    }

    func expandImmediately() {
        guard !isActivityDocked else { return }
        hoverExpansion?.cancel()
        hoverCollapse?.cancel()
        hoverExpansion = nil
        hoverCollapse = nil
        isPointerInside = true
        setExpanded(true)
    }

    /// Yukarı ok: Timer/Sayaç’ı adaya kilitle; hover kapalı, aşağı ok açık.
    func dockActivityToIsland() {
        guard selectedTab.canDockToIsland else { return }
        hoverExpansion?.cancel()
        hoverCollapse?.cancel()
        hoverExpansion = nil
        hoverCollapse = nil
        isActivityDocked = true
        isPinned = false
        isPointerInside = false
        setExpanded(false)
    }

    /// Ada üzerindeki aşağı ok → tam paneli aç.
    func expandFromDock() {
        hoverExpansion?.cancel()
        hoverCollapse?.cancel()
        isActivityDocked = false
        isPointerInside = true
        setExpanded(true)
    }

    func openSettings() {
        SettingsWindowController.shared.show(model: self)
    }

    /// ⌃⌥D — ada aç/kapa.
    func toggleIslandFromHotKey() {
        if isActivityDocked {
            expandFromDock()
            return
        }
        if isExpanded {
            isPinned = false
            isPointerInside = false
            setExpanded(false)
        } else {
            isPointerInside = true
            setExpanded(true)
        }
    }

    func togglePin() {
        let willPin = !isPinned
        isPinned = willPin
        if willPin {
            isActivityDocked = false
            setExpanded(true)
        } else if !isPointerInside {
            setExpanded(false)
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func forceExpandedForLaunch() {
        launchReveal = 1
        isExpanded = true
        showsExpandedContent = true
        isPinned = true
        isActivityDocked = false
    }

#if DEBUG
    func debugToggleExpanded() {
        isPinned = false
        isActivityDocked = false
        if isExpanded {
            isPointerInside = false
            setExpanded(false)
        } else {
            isPointerInside = true
            setExpanded(true)
        }
    }
#endif

    /// İçerik takası yok: pencere hedefe gider, öğeler `morphProgress` ile
    /// aynı karede kendi boyutlarına büyür/küçülür.
    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        showsExpandedContent = expanded
    }
}
