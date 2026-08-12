import AppKit
import Combine
import QuartzCore
import SwiftUI

private final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// NSHostingView'un pencere boyutuna / Auto Layout'a geri beslenmesini keser.
private final class SolidHitHostingView<Content: View>: NSHostingView<Content> {
    override var intrinsicContentSize: NSSize { bounds.size }

    override func invalidateIntrinsicContentSize() {}

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point) {
            return hit
        }
        return bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// CADisplayLink @objc hedefi ister; controller NSObject değil.
private final class DisplayLinkProxy: NSObject {
    var onTick: (() -> Void)?

    @objc func tick(_ sender: CADisplayLink) {
        onTick?()
    }
}

@MainActor
final class IslandPanelController {
    private enum Layout {
        /// Kamera lobları + sağdaki tıklanabilir kontroller için ekstra genişlik.
        static let collapsedWidthExtra: CGFloat = 112
        static let collapsedMinHeight: CGFloat = 33
        static let notchCornerRadius: CGFloat = 18
        /// Referans DI medya hapı oranına yakın yedek boyut.
        static let fallbackCollapsed = NSSize(width: 294, height: 33)
        static let expanded = NSSize(width: 600, height: 268)
        static let expandedHoverPad: CGFloat = 8
    }

    private struct ScreenAnchor {
        let centerX: CGFloat
        let collapsedSize: NSSize
        let topY: CGFloat
        let menuBarHeight: CGFloat
        let cornerRadius: CGFloat
    }

    private let model: AppModel
    private let panel: IslandPanel
    private var hostingView: SolidHitHostingView<IslandRootView>!
    private var cancellables = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var resignActiveObserver: NSObjectProtocol?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var hoverPollTimer: Timer?
    private var keepFrontTimer: Timer?
    private var missionControlTimer: Timer?
    private var frameAnimationTimer: Timer?
    private var frameAnimationLink: CADisplayLink?
    private var frameAnimationProxy: DisplayLinkProxy?
    private var launchRevealTimer: Timer?
    private var isAnimatingFrame = false
    /// Morph ilerlemesi için referans yükseklikler.
    private var collapsedHeightForMorph: CGFloat = 33
    /// Mission Control / Exposé kaydırma ilerlemesi 0…1 (senkron kayma).
    private var missionControlProgress: CGFloat = 0
    private var pendingProgress: CGFloat?
    /// MC sırasında bozulmasın diye son “dinlenme” karesi.
    private var restPanelFrame: NSRect = .zero
    private var isPointerInside = false
    /// Animasyon sırasında hover kaçmasın diye bekleyen durum.
    private var pendingHoverInside: Bool?
    /// Ada yalnızca bu ekranda durur; tıklanan ekrana kayarak geçer.
    private var activeScreenID: ObjectIdentifier?
    /// Ekranlar arası yatay kayma (morph değil).
    private var isSlidingBetweenScreens = false
    /// Kayma / hemen ardından daralma sırasında MC fade ve z-order düşmesini engelle.
    private var suppressMissionControlUntil: CFTimeInterval = 0
    /// Ekran kayması sonrası sabitlenmemiş collapse’ı ertele.
    private var suppressHoverCollapseUntil: CFTimeInterval = 0
    private var pendingAdoptScreenID: ObjectIdentifier?
    private var adoptDebounceWork: DispatchWorkItem?

    /// Menü / tam ekran / diğer panellerin üstünde kalsın.
    private static var overlayLevel: NSWindow.Level {
        NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)) + 25)
    }

    private var isMissionControlSuppressed: Bool {
        isSlidingBetweenScreens || CACurrentMediaTime() < suppressMissionControlUntil
    }

    init(model: AppModel) {
        self.model = model
        panel = IslandPanel(
            contentRect: NSRect(origin: .zero, size: Layout.fallbackCollapsed),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        observeModel()
        startHoverMonitoring()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
        }
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        hoverPollTimer?.invalidate()
        keepFrontTimer?.invalidate()
        missionControlTimer?.invalidate()
        frameAnimationTimer?.invalidate()
        frameAnimationLink?.invalidate()
        launchRevealTimer?.invalidate()
        adoptDebounceWork?.cancel()
    }

    func show() {
        lockToHomeScreen(animated: false)
        panel.orderFrontRegardless()
        joinNotchSpace(panel)
        pollHover()
        startLaunchReveal()
    }

    /// Açılış: ada çentik genişliğinde durur, sonra yavaşça iki yana büyür.
    private func startLaunchReveal() {
        guard model.launchReveal < 1, !model.isExpanded else {
            model.launchReveal = 1
            reposition(animated: false)
            return
        }

        model.launchReveal = 0
        reposition(animated: false)

        let duration: CFTimeInterval = 1.52
        var startTime: CFTimeInterval?

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let now = CACurrentMediaTime()
            // Kısa bir merkez pozu, sonra yavaş genişleme.
            let begin = startTime ?? (now + 0.18)
            startTime = begin
            guard now >= begin else { return }

            let raw = min(1, max(0, (now - begin) / duration))
            self.model.launchReveal = Self.easeInOutCubic(CGFloat(raw))
            self.reposition(animated: false)

            if raw >= 1 {
                timer.invalidate()
                self.launchRevealTimer = nil
                self.model.launchReveal = 1
                self.reposition(animated: false)
                self.joinNotchSpace(self.panel)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        launchRevealTimer = timer
    }

    /// 3 parmak Space’te ada fiziksel ekranı (çentiği) takip etsin — masaüstü
    /// kayarken ada yerinde kalsın. NotchSpace + stationary ile sabitlenir.
    private func joinNotchSpace(_ window: NSWindow, retries: Int = 8) {
        if window.windowNumber > 0 {
            NotchSpace.shared.attach(window)
            return
        }
        guard retries > 0 else { return }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            self.joinNotchSpace(window, retries: retries - 1)
        }
    }

    /// Ada tüm Space’lerde ana ekran çentiğinde sabit; diğer monitöre gitmez.
    private func updateCollectionBehavior(slidingBetweenScreens: Bool = false) {
        _ = slidingBetweenScreens
        var behavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        if #available(macOS 13.0, *) {
            behavior.insert(.canJoinAllApplications)
        }
        panel.collectionBehavior = behavior
    }

    func writeSnapshot(to url: URL) throws {
        guard let view = panel.contentView else { return }
        view.layoutSubtreeIfNeeded()

        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            return
        }
        try data.write(to: url, options: .atomic)
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Menü çubuğu / çentik / tam ekran uygulamaların üstünde.
        panel.level = Self.overlayLevel
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false
        panel.contentMinSize = .zero
        panel.contentMaxSize = NSSize(width: 2_000, height: 2_000)
        updateCollectionBehavior()

        let rootView = IslandRootView(model: model)
        let hosting = SolidHitHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.frame = NSRect(origin: .zero, size: Layout.fallbackCollapsed)
        panel.contentView = hosting
        hostingView = hosting

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.lockToHomeScreen(animated: false)
            }
        }

        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Space bitti: ada hâlâ ana çentikte — frame + NotchSpace yenile.
                guard let self else { return }
                self.missionControlProgress = 0
                self.pendingProgress = nil
                self.panel.alphaValue = 1
                self.lockToHomeScreen(animated: false)
                self.enforceNotchAnchor()
                self.refreshPanelPresence()
            }
        }

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.panel.alphaValue = 1
                self.keepPanelsFrontmost()
            }
        }
    }

    private func observeModel() {
        model.$isExpanded
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                guard let self else { return }
                // Ekran kaymasını yarıda kesme — aksi halde ada ekranlar
                // arasındaki boşlukta (off-screen) kalıyor.
                if self.isSlidingBetweenScreens {
                    self.pendingHoverInside = nil
                    return
                }
                if expanded {
                    self.makeInteractive()
                }
                self.reposition(animated: true)
            }
            .store(in: &cancellables)

        model.$isPinned
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.isSlidingBetweenScreens else { return }
                self.reposition(animated: true)
            }
            .store(in: &cancellables)

        model.$selectedTab
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.isSlidingBetweenScreens else { return }
                self.reposition(animated: true)
            }
            .store(in: &cancellables)

        model.$menuBarHeight
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self,
                      self.model.isExpanded,
                      !self.isSlidingBetweenScreens,
                      !self.isAnimatingFrame else { return }
                self.reposition(animated: true)
            }
            .store(in: &cancellables)

        // Ada içeriği (süre biçimi, sayaç hanesi) uzayınca kanatlar büyür.
        model.$islandSideExtra
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.isSlidingBetweenScreens, !self.isAnimatingFrame else { return }
                self.reposition(animated: true)
            }
            .store(in: &cancellables)
    }

    private var lastCompactClickUptime: TimeInterval = 0

    private func startHoverMonitoring() {
        // Konum poll: global monitor bazı uygulamalarda (tarayıcı / oyun) kaçabiliyor.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.pollHover()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverPollTimer = timer

        // Ada her zaman en üstte; çoklu ekranda daha sık öne al (kompakt z-order).
        let frontInterval: TimeInterval = NSScreen.screens.count > 1 ? 0.22 : 0.75
        let front = Timer(timeInterval: frontInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.isMissionControlSuppressed {
                    self.panel.alphaValue = 1
                    self.keepPanelsFrontmost()
                    return
                }
                guard self.missionControlProgress < 0.05 else { return }
                self.keepPanelsFrontmost()
            }
        }
        RunLoop.main.add(front, forMode: .common)
        keepFrontTimer = front

        // Mission Control: parmak ilerlemesiyle senkron yukarı/aşağı kayma.
        let mc = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.pollMissionControlProgress()
            }
        }
        RunLoop.main.add(mc, forMode: .common)
        missionControlTimer = mc

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .leftMouseDown {
                // Menü çubuğu/çentik bölgesinde SwiftUI tıklama almaz; AppKit’ten yönlendir.
                if self.handleCompactControlClick(at: NSEvent.mouseLocation) {
                    return nil
                }
                self.handlePossibleClickSynchronously()
            }
            DispatchQueue.main.async {
                self.pollHover()
            }
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown]
        ) { [weak self] event in
            DispatchQueue.main.async {
                guard let self else { return }
                if event.type == .leftMouseDown {
                    // Uygulama aktif değilken de kompakt butonlar çalışsın.
                    _ = self.handleCompactControlClick(at: NSEvent.mouseLocation)
                }
                self.pollHover()
            }
        }
    }

    /// Collapsed Timer/Sayaç: sağ lobdaki buton bölgelerini ekran koordinatından çöz.
    /// Çentik/menü çubuğunda SwiftUI gesture çoğu zaman hiç tetiklenmez.
    @discardableResult
    private func handleCompactControlClick(at screenPoint: NSPoint) -> Bool {
        guard !model.isExpanded, !model.showsExpandedContent else { return false }
        guard model.selectedTab.canDockToIsland else { return false }
        guard let hitPanel = panelContaining(screenPoint) else { return false }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastCompactClickUptime > 0.18 else { return true }
        lastCompactClickUptime = now

        let fromTrailing = hitPanel.frame.maxX - screenPoint.x
        // Docked yerleşim (sağdan): chevron inset 6 / Ø20 → ~6…26;
        // play/+/tik inset 31 / Ø22 → ~31…53. Bölgeler çakışmasın.
        // Görevler tik’i dock değilken de sağda — biraz daha geniş hit.
        let primaryZone: CGFloat = model.selectedTab == .tasks ? 52 : 36
        if model.isActivityDocked {
            if fromTrailing <= 28 {
                model.expandFromDock()
                makeInteractive()
                return true
            }
            if fromTrailing <= 64 {
                performPrimaryCompactAction()
                return true
            }
        } else if fromTrailing <= primaryZone {
            performPrimaryCompactAction()
            return true
        }

        return false
    }

    private func panelContaining(_ screenPoint: NSPoint) -> IslandPanel? {
        panel.frame.contains(screenPoint) ? panel : nil
    }

    private func performPrimaryCompactAction() {
        switch model.selectedTab {
        case .timer:
            model.timer.toggle()
        case .counter:
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                model.counter.increment()
            }
        case .tasks:
            // Animasyon completeSelected içinde yayınlanır; burada sarmalama
            // çift tetik / stale state riskini artırıyordu.
            _ = model.tasks.completeSelected()
        default:
            break
        }
    }

    private func handlePossibleClickSynchronously() {
        guard hoverHitRect(entering: true).contains(NSEvent.mouseLocation) else { return }
        makeInteractive()
        let hasCompactControls = model.isActivityDocked || model.selectedTab.canDockToIsland
        guard !hasCompactControls else { return }
        if !model.isExpanded {
            model.expandImmediately()
        }
    }

    private func makeInteractive() {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        if !panel.isKeyWindow {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func pollHover() {
        let mouse = NSEvent.mouseLocation
        // Ada yalnızca ana ekranda — diğer monitörlere takip yok.

        let inside: Bool
        if model.isExpanded {
            if isPointerInside || pendingHoverInside == true {
                inside = hoverHitRect(entering: false).contains(mouse)
            } else {
                inside = hoverHitRect(entering: true).contains(mouse)
            }
        } else {
            inside = panelContaining(mouse) != nil
        }

        if isAnimatingFrame || isSlidingBetweenScreens {
            pendingHoverInside = inside
            return
        }

        applyHover(inside)
    }

    private func applyHover(_ inside: Bool) {
        pendingHoverInside = nil
        guard inside != isPointerInside else { return }
        isPointerInside = inside
        // Kompakt Timer/Sayaç kontrolleri tıklanabilsin diye fare girince key yap.
        if inside, !model.isExpanded, (model.isActivityDocked || model.selectedTab.canDockToIsland) {
            makeInteractive()
        }
        // Ekran kayması sonrası collapse ikinci animasyonu kaymayı kesip adayı
        // off-screen bırakıyordu (sabitliyken collapse yok → sorun yoktu).
        if !inside,
           !model.isPinned,
           CACurrentMediaTime() < suppressHoverCollapseUntil {
            model.syncPointerInside(false)
            return
        }
        model.hoverChanged(isInside: inside)
    }

    /// Daraltılmışken yalnızca gerçek çentik dikdörtgeni — alt/sağ/sol pad yok.
    private func hoverHitRect(entering: Bool) -> NSRect {
        if model.isExpanded {
            let pad = Layout.expandedHoverPad + (entering ? 0 : 4)
            return panel.frame.insetBy(dx: -pad, dy: -pad)
        }

        // Collapsed: yalnızca aktif ekrandaki panel.
        return panel.frame
    }

    private func reposition(animated: Bool) {
        guard let screen = homeScreen() else { return }
        let anchor = screenAnchor(for: screen)

        if abs(model.menuBarHeight - anchor.menuBarHeight) > 0.5 {
            model.menuBarHeight = anchor.menuBarHeight
        }
        if abs(model.islandCornerRadius - anchor.cornerRadius) > 0.5 {
            model.islandCornerRadius = anchor.cornerRadius
        }
        collapsedHeightForMorph = anchor.collapsedSize.height
        let collapsed = CGSize(
            width: anchor.collapsedSize.width,
            height: anchor.collapsedSize.height
        )
        if model.collapsedPanelSize != collapsed {
            model.collapsedPanelSize = collapsed
        }

        let size: NSSize
        if model.isExpanded {
            let target = model.expandedPanelSize
            size = NSSize(width: target.width, height: target.height)
        } else {
            size = anchor.collapsedSize
        }
        let frame = clampFrame(
            NSRect(
                x: (anchor.centerX - (size.width / 2)).rounded(.toNearestOrAwayFromZero),
                y: (anchor.topY - size.height).rounded(.toNearestOrAwayFromZero),
                width: size.width.rounded(.toNearestOrAwayFromZero),
                height: size.height.rounded(.toNearestOrAwayFromZero)
            ),
            to: screen
        )
        restPanelFrame = frame

        if missionControlProgress > 0.01, !isMissionControlSuppressed {
            applyMissionControlVisuals(progress: missionControlProgress)
            return
        }

        guard !NSEqualRects(panel.frame, frame) else {
            keepPanelsFrontmost()
            return
        }

        guard animated, panel.isVisible else {
            applyFrame(frame)
            return
        }

        let screenSlide = abs(panel.frame.midX - frame.midX) > max(panel.frame.width, frame.width)
            || abs(panel.frame.maxY - frame.maxY) > 40
        if screenSlide {
            beginScreenSlide()
        }
        animateFrame(to: frame, expanding: model.isExpanded, screenSlide: screenSlide)
    }

    /// Kayma başlamadan görünürlüğü ve space durumunu sabitle — aksi halde
    /// CGS space / MC fade ada kaybolmuş gibi görünüyor.
    private func beginScreenSlide() {
        isSlidingBetweenScreens = true
        suppressMissionControlUntil = CACurrentMediaTime() + 1.25
        suppressHoverCollapseUntil = CACurrentMediaTime() + 1.6
        missionControlProgress = 0
        pendingProgress = nil
        model.cancelPendingHover()
        isPointerInside = false
        model.syncPointerInside(false)
        panel.alphaValue = 1
        NotchSpace.shared.detach(panel)
        panel.level = Self.overlayLevel
        panel.orderFrontRegardless()
    }

    private func keepPanelsFrontmost() {
        if isMissionControlSuppressed {
            panel.alphaValue = 1
            panel.level = Self.overlayLevel
            if panel.isVisible {
                panel.orderFrontRegardless()
                joinNotchSpace(panel)
            }
            return
        }
        guard missionControlProgress < 0.85 else { return }
        panel.level = Self.overlayLevel
        if panel.isVisible || missionControlProgress > 0.01 {
            panel.orderFrontRegardless()
            joinNotchSpace(panel)
        }
    }

    /// NotchSpace + öne al — 3 parmakta fiziksel ekranı takip etsin.
    private func refreshPanelPresence() {
        panel.alphaValue = 1
        panel.level = Self.overlayLevel
        updateCollectionBehavior()
        panel.orderFrontRegardless()
        joinNotchSpace(panel)
        panel.orderFrontRegardless()
    }

    /// Hedef ekranın frame’i içinde tut.
    private func clampFrame(_ frame: NSRect, to screen: NSScreen) -> NSRect {
        var f = frame
        let bounds = screen.frame
        if f.height > bounds.height {
            f.size.height = bounds.height
        }
        if f.width > bounds.width {
            f.size.width = bounds.width
        }
        if f.maxY > bounds.maxY {
            f.origin.y = bounds.maxY - f.height
        }
        if f.minY < bounds.minY {
            f.origin.y = bounds.minY
        }
        if f.minX < bounds.minX {
            f.origin.x = bounds.minX
        }
        if f.maxX > bounds.maxX {
            f.origin.x = bounds.maxX - f.width
        }
        return f
    }

    private func pollMissionControlProgress() {
        guard !isMissionControlSuppressed else {
            if panel.alphaValue < 0.999 { panel.alphaValue = 1 }
            enforceNotchAnchor()
            return
        }
        updateMissionControlProgress()
        // 3 parmak Space: her karede çentiğe kilitle — ekranı takip etsin.
        enforceNotchAnchor()
    }

    /// Space kaydırırken macOS paneli sürüklemesin; ana ekran çentiğinde tut.
    private func enforceNotchAnchor() {
        guard missionControlProgress < 0.02,
              !isAnimatingFrame,
              !isSlidingBetweenScreens,
              restPanelFrame.width > 1 else { return }

        if panel.alphaValue != 1 { panel.alphaValue = 1 }
        if !NSEqualRects(panel.frame, restPanelFrame) {
            panel.setFrame(restPanelFrame, display: false)
        }
        panel.level = Self.overlayLevel
        panel.orderFrontRegardless()
        joinNotchSpace(panel)
    }

    private func updateMissionControlProgress() {
        let next = Self.estimateMissionControlProgress()

        // Geçiş penceresi ile Dock overlay'inin devir teslim anında tek karelik
        // 0↔1 sıçramaları oluyor; büyük atlamalar için iki ardışık örnek iste.
        if abs(next - missionControlProgress) > 0.5 {
            guard let pending = pendingProgress, abs(pending - next) < 0.1 else {
                pendingProgress = next
                return
            }
        }
        pendingProgress = nil

        // Çok hafif smoothing — sinyal zaten parmakla birebir, gecikme istemiyoruz.
        let smoothed: CGFloat
        if abs(next - missionControlProgress) < 0.004 {
            smoothed = next
        } else {
            smoothed = missionControlProgress + (next - missionControlProgress) * 0.7
        }
        let clamped = max(0, min(1, smoothed))
        guard abs(clamped - missionControlProgress) > 0.001 else { return }
        missionControlProgress = clamped
        applyMissionControlVisuals(progress: clamped)
    }

    /// 0…1 Mission Control ilerlemesi.
    ///
    /// Yalnızca gerçek Mission Control (üst swipe / F3): Dock’un küçültülmüş
    /// masaüstü katmanı + tam ekran overlay’leri. 3 parmak yatay Space geçişi
    /// bu sinyali üretmemeli — aksi halde ada yukarı kayıp kaybolur; Space’te
    /// ada çentik / üst ortada sabit kalmalı.
    private static func estimateMissionControlProgress() -> CGFloat {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return 0
        }

        var fullScreenOverlays = 0
        var transition: CGFloat?

        for window in info {
            guard (window[kCGWindowOwnerName as String] as? String) == "Dock" else { continue }

            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            let name = window[kCGWindowName as String] as? String
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"],
                  width > 1, height > 1 else { continue }

            let rect = CGRect(x: x, y: y, width: width, height: height)
            guard let display = displayBounds(containing: rect) else { continue }

            if (16...25).contains(layer),
               width >= display.width * 0.9,
               height >= display.height * 0.9 {
                fullScreenOverlays += 1
                continue
            }

            if layer < -2_000_000_000, name == nil {
                let scale = min(width / display.width, height / display.height)
                if scale > 0.02, scale < 0.995 {
                    transition = max(transition ?? 0, 1 - scale)
                }
            }
        }

        // Yatay Space swipe bazen zayıf transition penceresi üretir; yalnızca
        // gerçek MC overlay’leriyle birlikte gizle.
        if fullScreenOverlays >= 2 {
            return transition.map { min(1, max($0, 0.85)) } ?? 1
        }
        if let transition, transition > 0.35, fullScreenOverlays >= 1 {
            return min(1, transition)
        }
        return 0
    }

    private static func displayBounds(containing rect: CGRect) -> CGRect? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return nil }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        var largest: CGRect?
        for id in ids {
            let bounds = CGDisplayBounds(id)
            if bounds.contains(center) { return bounds }
            if largest == nil || bounds.width * bounds.height > largest!.width * largest!.height {
                largest = bounds
            }
        }
        return largest
    }

    private func applyMissionControlVisuals(progress: CGFloat) {
        let rest = restPanelFrame
        guard rest.width > 1, rest.height > 1 else { return }

        // Yukarı kayma + fade — parmak ilerlemesiyle orantılı.
        let travel = rest.height + max(model.menuBarHeight, 33) + 28
        var frame = rest
        frame.origin.y = rest.origin.y + travel * progress
        panel.alphaValue = max(0, 1 - progress * 1.05)
        panel.setFrame(frame, display: true)

        if progress > 0.02 {
            panel.orderFrontRegardless()
        }

        if progress < 0.02 {
            panel.alphaValue = 1
            if !NSEqualRects(panel.frame, rest) {
                panel.setFrame(rest, display: true)
            }
        }
    }

    private func applyFrame(_ frame: NSRect) {
        stopFrameAnimation()
        isAnimatingFrame = false
        isSlidingBetweenScreens = false
        updateCollectionBehavior()
        panel.alphaValue = 1
        panel.setFrame(frame, display: true)
        syncMorphProgress(height: frame.height)
        panel.orderFrontRegardless()
        joinNotchSpace(panel)
        keepPanelsFrontmost()
        if let pending = pendingHoverInside {
            applyHover(pending)
        } else {
            pollHover()
        }
    }

    private func animateFrame(to target: NSRect, expanding: Bool, screenSlide: Bool = false) {
        stopFrameAnimation()

        let start = panel.frame
        let duration: CFTimeInterval
        if screenSlide {
            duration = 0.58
            isSlidingBetweenScreens = true
            suppressMissionControlUntil = CACurrentMediaTime() + 1.25
        } else {
            duration = expanding ? 0.50 : 0.42
            isSlidingBetweenScreens = false
            if CACurrentMediaTime() < suppressMissionControlUntil {
                suppressMissionControlUntil = max(
                    suppressMissionControlUntil,
                    CACurrentMediaTime() + 0.9
                )
            }
        }
        let startTime = CACurrentMediaTime()
        isAnimatingFrame = true
        panel.alphaValue = 1
        panel.level = Self.overlayLevel
        panel.orderFrontRegardless()

        let step: () -> Void = { [weak self] in
            guard let self else { return }

            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(1, elapsed / duration)
            let eased = screenSlide ? Self.easeInOutCubic(progress) : Self.springOut(progress)
            let frame: NSRect
            if screenSlide {
                let x = start.origin.x + (target.origin.x - start.origin.x) * eased
                let y = start.origin.y + (target.origin.y - start.origin.y) * eased
                let w = start.width + (target.width - start.width) * eased
                let h = start.height + (target.height - start.height) * eased
                frame = NSRect(x: x, y: y, width: w, height: h)
            } else {
                frame = Self.lerp(start, target, eased)
            }

            self.panel.alphaValue = 1
            self.panel.setFrame(frame, display: true)
            self.panel.level = Self.overlayLevel
            // Fiziksel ekran kaymasında her karede önde tut (sabitlenmemiş kompakt).
            if screenSlide || NSScreen.screens.count > 1 {
                self.panel.orderFrontRegardless()
            }
            if !screenSlide {
                self.syncMorphProgress(height: frame.height)
            }

            if progress >= 1 {
                self.stopFrameAnimation()
                self.panel.alphaValue = 1
                self.panel.setFrame(target, display: true)
                self.syncMorphProgress(height: target.height)
                self.isAnimatingFrame = false
                let wasScreenSlide = screenSlide
                self.isSlidingBetweenScreens = false
                self.updateCollectionBehavior()
                self.restPanelFrame = target
                if wasScreenSlide {
                    self.suppressMissionControlUntil = CACurrentMediaTime() + 1.4
                }
                self.panel.level = Self.overlayLevel
                self.panel.orderFrontRegardless()
                if wasScreenSlide {
                    self.panel.setFrame(target, display: true)
                    self.restPanelFrame = target
                    if let screen = self.homeScreen(),
                       !screen.frame.intersects(self.panel.frame.insetBy(dx: 4, dy: 4)) {
                        let clamped = self.clampFrame(target, to: screen)
                        self.panel.setFrame(clamped, display: true)
                        self.restPanelFrame = clamped
                    }
                    self.refreshPanelPresence()
                } else {
                    self.joinNotchSpace(self.panel)
                    self.keepPanelsFrontmost()
                    if CACurrentMediaTime() < self.suppressMissionControlUntil {
                        self.refreshPanelPresence()
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    self?.keepPanelsFrontmost()
                }
                if wasScreenSlide {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        guard let self else { return }
                        self.refreshPanelPresence()
                        if let pending = self.pendingHoverInside {
                            self.applyHover(pending)
                        } else {
                            self.pollHover()
                        }
                    }
                    // Daralma 0.12s sonra gelebilir — bitince tekrar öne al.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                        self?.refreshPanelPresence()
                    }
                    return
                }

                if let pending = self.pendingHoverInside {
                    self.applyHover(pending)
                } else {
                    self.pollHover()
                }
            }
        }

        // Ekran yenileme hızına kilitli adım (ProMotion'da 120 Hz).
        if let host = panel.contentView {
            let proxy = DisplayLinkProxy()
            proxy.onTick = step
            let link = host.displayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
            link.add(to: .main, forMode: .common)
            frameAnimationProxy = proxy
            frameAnimationLink = link
            return
        }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            MainActor.assumeIsolated { step() }
        }
        RunLoop.main.add(timer, forMode: .common)
        frameAnimationTimer = timer
    }

    private func stopFrameAnimation() {
        frameAnimationTimer?.invalidate()
        frameAnimationTimer = nil
        frameAnimationLink?.invalidate()
        frameAnimationLink = nil
        frameAnimationProxy = nil
    }

    /// Pencerenin o anki yüksekliğinden morph ilerlemesi (0 = ada, 1 = panel).
    private func syncMorphProgress(height: CGFloat) {
        let collapsed = max(collapsedHeightForMorph, 1)
        let expanded = max(model.expandedPanelSize.height, collapsed + 1)
        let value = min(1, max(0, (height - collapsed) / (expanded - collapsed)))
        if abs(model.morphProgress - value) > 0.0005 {
            model.morphProgress = value
        }
    }

    private static func lerp(_ a: NSRect, _ b: NSRect, _ t: CGFloat) -> NSRect {
        NSRect(
            x: a.origin.x + (b.origin.x - a.origin.x) * t,
            y: a.origin.y + (b.origin.y - a.origin.y) * t,
            width: a.size.width + (b.size.width - a.size.width) * t,
            height: a.size.height + (b.size.height - a.size.height) * t
        )
    }

    private static func easeOutExpo(_ t: CGFloat) -> CGFloat {
        t >= 1 ? 1 : 1 - pow(2, -10 * t)
    }

    /// Kritik sönümlü yay. `easeOut*` aileleri aşırı ön yüklemeli olduğundan
    /// ilerlemenin yarısı ilk birkaç karede geçiyor ve içerik geçişleri
    /// "şak" diye oluyordu; bu eğri ilerlemeyi süreye dengeli yayar.
    private static func springOut(_ t: CGFloat) -> CGFloat {
        let k: CGFloat = 7
        let decay = exp(-k * t)
        return 1 - (1 + k * t) * decay
    }

    private static func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    private func screenAnchor(for screen: NSScreen) -> ScreenAnchor {
        let menuBarHeight = max(
            screen.frame.maxY - screen.visibleFrame.maxY,
            screen.safeAreaInsets.top,
            24
        )

        // Açılışta loblar çentiğin arkasından dışarı doğru büyür.
        // İçerik uzarsa (1 saati aşan süre, dört haneli sayaç) ada genişler.
        let sideExtra = model.islandSideExtra * min(1, max(0, model.launchReveal))

        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            // Çentiksiz (harici) ekran: kompakt ada menü çubuğunun ALTINDA dursun.
            // Aksi halde sabitlenmemişken menü bandında kalıp z-order’da kayboluyor;
            // sabitliyken geniş panel aşağı taştığı için “çalışıyor” gibi görünüyordu.
            let fallback = NSSize(
                width: (Layout.fallbackCollapsed.width - Layout.collapsedWidthExtra + sideExtra)
                    .rounded(.toNearestOrAwayFromZero),
                height: Layout.fallbackCollapsed.height
            )
            return ScreenAnchor(
                centerX: screen.frame.midX,
                collapsedSize: fallback,
                topY: screen.visibleFrame.maxY,
                menuBarHeight: menuBarHeight,
                cornerRadius: Layout.notchCornerRadius
            )
        }

        let notchWidth = rightArea.minX - leftArea.maxX
        guard notchWidth >= 120, notchWidth <= 360 else {
            let fallback = NSSize(
                width: (Layout.fallbackCollapsed.width - Layout.collapsedWidthExtra + sideExtra)
                    .rounded(.toNearestOrAwayFromZero),
                height: Layout.fallbackCollapsed.height
            )
            return ScreenAnchor(
                centerX: screen.frame.midX,
                collapsedSize: fallback,
                topY: screen.visibleFrame.maxY,
                menuBarHeight: menuBarHeight,
                cornerRadius: Layout.notchCornerRadius
            )
        }

        // Çentikli ekran: ada fiziksel çentikte (frame.maxY).
        let topY = screen.frame.maxY
        let notchHeight = max(leftArea.height, rightArea.height, screen.safeAreaInsets.top)
        let collapsedWidth = (notchWidth + sideExtra)
            .rounded(.toNearestOrAwayFromZero)
        let collapsedHeight = max(notchHeight - 3, Layout.collapsedMinHeight)
            .rounded(.toNearestOrAwayFromZero)

        return ScreenAnchor(
            centerX: leftArea.maxX + (notchWidth / 2),
            collapsedSize: NSSize(width: collapsedWidth, height: collapsedHeight),
            topY: topY,
            menuBarHeight: max(menuBarHeight, notchHeight),
            cornerRadius: collapsedHeight / 2
        )
    }

    /// Ana (tercihen çentikli) ekran — ada başka monitöre gitmez.
    private func homeScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: {
            $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil
        }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    /// Ada her zaman ana ekranda kalsın.
    private func lockToHomeScreen(animated: Bool) {
        guard let screen = homeScreen() else { return }
        let id = ObjectIdentifier(screen)
        activeScreenID = id
        adoptDebounceWork?.cancel()
        pendingAdoptScreenID = nil
        reposition(animated: animated && panel.isVisible)
    }
}
