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

    /// Menü / tam ekran / diğer panellerin üstünde kalsın.
    private static var overlayLevel: NSWindow.Level {
        NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)) + 25)
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
    }

    func show() {
        adoptScreen(under: NSEvent.mouseLocation, animated: false)
        reposition(animated: false)
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

    /// Paneli Space geçişlerinden tamamen muaf olan özel space'e taşı.
    /// Çoklu ekranda CGS özel space ada kaybolmasına yol açtığı için
    /// yalnızca tek ekranda kullanılır.
    private func joinNotchSpace(_ window: NSWindow, retries: Int = 8) {
        if NSScreen.screens.count > 1 {
            NotchSpace.shared.detach(window)
            return
        }
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
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            // stationary kaldırıldı: çoklu ekranda ada kayarak gidebilsin.
            // Spaces sabitliği NotchSpace ile sağlanıyor.
            .ignoresCycle
        ]
        if #available(macOS 13.0, *) {
            panel.collectionBehavior.insert(.canJoinAllApplications)
        }

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
                if let id = self.activeScreenID,
                   NSScreen.screens.contains(where: { ObjectIdentifier($0) == id }) {
                    self.reposition(animated: false)
                } else {
                    self.adoptScreen(under: NSEvent.mouseLocation, animated: false)
                }
            }
        }

        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Spaces: ada çentikte sabit; geçiş bitince öne al + space'e yeniden bağla.
                guard let self else { return }
                if self.missionControlProgress < 0.05 {
                    self.panel.alphaValue = 1
                    self.keepPanelsFrontmost()
                    self.reposition(animated: false)
                    self.joinNotchSpace(self.panel)
                }
            }
        }
    }

    private func observeModel() {
        model.$isExpanded
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                if expanded {
                    self?.makeInteractive()
                }
                self?.reposition(animated: true)
            }
            .store(in: &cancellables)

        model.$isPinned
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reposition(animated: true)
            }
            .store(in: &cancellables)

        model.$selectedTab
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reposition(animated: true)
            }
            .store(in: &cancellables)

        model.$menuBarHeight
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.model.isExpanded else { return }
                self.reposition(animated: true)
            }
            .store(in: &cancellables)

        // Ada içeriği (süre biçimi, sayaç hanesi) uzayınca kanatlar büyür.
        model.$islandSideExtra
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reposition(animated: true)
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

        // Ada her zaman en üstte + çoklu ekran aynaları.
        let front = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
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
                self.adoptScreen(under: NSEvent.mouseLocation, animated: true)
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
                    self.adoptScreen(under: NSEvent.mouseLocation, animated: true)
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
        // play/+ inset 31 / Ø22 → ~31…53. Bölgeler çakışmasın.
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
        } else if fromTrailing <= 36 {
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

        if isAnimatingFrame {
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
        guard let screen = targetScreen() else { return }
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
        let frame = NSRect(
            x: (anchor.centerX - (size.width / 2)).rounded(.toNearestOrAwayFromZero),
            y: (anchor.topY - size.height).rounded(.toNearestOrAwayFromZero),
            width: size.width.rounded(.toNearestOrAwayFromZero),
            height: size.height.rounded(.toNearestOrAwayFromZero)
        )
        restPanelFrame = frame

        if missionControlProgress > 0.01 {
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
        missionControlProgress = 0
        pendingProgress = nil
        panel.alphaValue = 1
        NotchSpace.shared.detach(panel)
        panel.orderFrontRegardless()
        panel.level = Self.overlayLevel
    }

    private func keepPanelsFrontmost() {
        guard missionControlProgress < 0.85 else { return }
        panel.level = Self.overlayLevel
        if panel.isVisible || missionControlProgress > 0.01 {
            panel.orderFrontRegardless()
            joinNotchSpace(panel)
        }
    }

    private func pollMissionControlProgress() {
        // Ekranlar arası kayarken MC sinyali yanlışlıkla alpha'yı 0 yapabiliyor.
        guard !isSlidingBetweenScreens else { return }
        updateMissionControlProgress()
        enforceNotchAnchor()
    }

    /// Space geçişinde macOS paneli eski masaüstüyle birlikte kaydırabiliyor;
    /// her karede çentik altındaki hedef kareye geri kilitle ve öne al.
    private func enforceNotchAnchor() {
        guard missionControlProgress < 0.02,
              !isAnimatingFrame,
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
    /// Geçiş sırasında Dock, masaüstünün küçültülmüş bir kopyasını adsız bir
    /// masaüstü katmanı penceresi olarak çizer; bu pencerenin ölçeği parmakla
    /// birebir değişir. Mission Control tam açıkken bu pencere kaybolur ve
    /// yerine Dock'un tam ekran overlay pencereleri gelir.
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

        if let transition { return min(1, transition) }
        return fullScreenOverlays >= 2 ? 1 : 0
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
        } else {
            duration = expanding ? 0.50 : 0.42
            isSlidingBetweenScreens = false
        }
        let startTime = CACurrentMediaTime()
        isAnimatingFrame = true
        if screenSlide {
            panel.alphaValue = 1
        }

        let step: () -> Void = { [weak self] in
            guard let self else { return }

            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(1, elapsed / duration)
            let eased = screenSlide ? Self.easeInOutCubic(progress) : Self.springOut(progress)
            // Üst kenardan yatay kayma: X yumuşak, Y her karede hedefe yakın
            // tutularak ekranlar arası boşlukta kaybolmasın.
            let frame: NSRect
            if screenSlide {
                let x = start.origin.x + (target.origin.x - start.origin.x) * eased
                let y = start.origin.y + (target.origin.y - start.origin.y) * eased
                let w = start.width + (target.width - start.width) * eased
                let h = start.height + (target.height - start.height) * eased
                frame = NSRect(x: x, y: y, width: w, height: h)
                self.panel.alphaValue = 1
            } else {
                frame = Self.lerp(start, target, eased)
            }

            self.panel.setFrame(frame, display: true)
            if !screenSlide {
                self.syncMorphProgress(height: frame.height)
            }

            if progress >= 1 {
                self.stopFrameAnimation()
                self.panel.alphaValue = 1
                self.panel.setFrame(target, display: true)
                self.syncMorphProgress(height: target.height)
                self.isAnimatingFrame = false
                self.isSlidingBetweenScreens = false
                self.restPanelFrame = target
                self.panel.level = Self.overlayLevel
                self.panel.orderFrontRegardless()
                self.joinNotchSpace(self.panel)

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
        let topY = screen.frame.maxY
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
            let fallback = NSSize(
                width: (Layout.fallbackCollapsed.width - Layout.collapsedWidthExtra + sideExtra)
                    .rounded(.toNearestOrAwayFromZero),
                height: Layout.fallbackCollapsed.height
            )
            return ScreenAnchor(
                centerX: screen.frame.midX,
                collapsedSize: fallback,
                topY: topY,
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
                topY: topY,
                menuBarHeight: menuBarHeight,
                cornerRadius: Layout.notchCornerRadius
            )
        }

        let notchHeight = max(leftArea.height, rightArea.height, screen.safeAreaInsets.top)
        // Referans DI hapı: çentikten geniş; yükseklik ~2px daha sıkı.
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

    private func targetScreen() -> NSScreen? {
        if let id = activeScreenID,
           let screen = NSScreen.screens.first(where: { ObjectIdentifier($0) == id }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    /// Tıklanan (veya fare altındaki) ekranı aktif yap; gerekirse üst kenardan
    /// sola/sağa kayarak oraya taşı.
    private func adoptScreen(under point: NSPoint, animated: Bool) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) })
                ?? NSScreen.main
                ?? NSScreen.screens.first else { return }
        let id = ObjectIdentifier(screen)
        if activeScreenID == id {
            // Ekran hâlâ bağlı; yapılandırma değişmediyse çık.
            return
        }
        activeScreenID = id
        reposition(animated: animated && panel.isVisible)
    }
}
