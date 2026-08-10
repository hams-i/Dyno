import AppKit
import SwiftUI

struct ExpandedIslandView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var prefs = PreferencesStore.shared

    @State private var isShowingClearConfirmation = false
    @State private var dragTranslation: CGFloat = 0
    @State private var tabFrames: [Int: CGRect] = [:]

    private var pageWidth: CGFloat { model.pageWidth }

    private var tabSpring: Animation {
        .spring(response: 0.36, dampingFraction: 0.88)
    }

    var body: some View {
        standardLayout
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .id(prefs.preferences.languageCode)
            .confirmationDialog(
                L10n.clipboardClearConfirmTitle,
                isPresented: $isShowingClearConfirmation
            ) {
                Button(L10n.clipboardClearConfirmAction, role: .destructive) {
                    model.clipboard.clear()
                }
                Button(L10n.clipboardClearConfirmCancel, role: .cancel) {}
            } message: {
                Text(L10n.clipboardClearConfirmMessage)
            }
    }

    private var standardLayout: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: model.menuBarHeight)
                .allowsHitTesting(false)

            header
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 10)

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.horizontal, 18)

            tabPages
                .morphSlot(.pagesArea)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// Sayfalar yan yana; parmakla birebir kayar, bırakınca en yakın sayfaya oturur.
    private var tabPages: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            HStack(spacing: 0) {
                ForEach(IslandTab.allCases) { tab in
                    page(for: tab)
                        .frame(width: width, height: proxy.size.height, alignment: .top)
                        // Yalnızca görünen sekme morph hedeflerini bildirir.
                        .environment(\.morphRecording, model.selectedTab == tab)
                }
            }
            // Kayma tek bir yayınlanmış değerden okunur; morph öğeleri de aynı
            // değeri izlediği için sayfalarıyla birebir birlikte hareket eder.
            .offset(x: model.pageScroll)
            .frame(width: width, height: proxy.size.height, alignment: .leading)
            .onAppear { adoptPageWidth(width) }
            .onChange(of: width) { _, newValue in adoptPageWidth(newValue) }
            // Sekme dışarıdan da değişebilir (menü, adaya küçültme).
            .onChange(of: model.selectedTab) { _, _ in
                withAnimation(tabSpring) { syncPageScroll() }
            }
            .background {
                HorizontalTabSwipeCatcher(
                    isEnabled: isInteractive,
                    onChange: { delta in
                        dragTranslation = rubberBanded(dragTranslation + delta)
                        syncPageScroll()
                    },
                    onEnd: { finish() },
                    onStep: { step in advanceTab(by: step) }
                )
            }
        }
        .clipped()
    }

    /// Panel kapalıyken geniş yerleşim sahnede ama görünmez durur; kaydırma
    /// olayları bu haldeyken sekme değiştirmemeli.
    private var isInteractive: Bool {
        model.morphProgress > 0.9
    }

    private func adoptPageWidth(_ width: CGFloat) {
        guard abs(model.pageWidth - width) > 0.5 else { return }
        model.pageWidth = width
        syncPageScroll()
    }

    private func syncPageScroll() {
        model.pageScroll = model.restScroll(for: model.selectedTab) + dragTranslation
    }

    /// Kenarlarda direnç — ilk/son sayfada parmak boşa gitmesin.
    private func rubberBanded(_ value: CGFloat) -> CGFloat {
        let index = model.selectedTab.pageIndex
        let isFirst = index == 0
        let isLast = index == IslandTab.allCases.count - 1
        if (isFirst && value > 0) || (isLast && value < 0) {
            return value * 0.3
        }
        return value
    }

    private func finish() {
        let threshold = max(pageWidth * 0.10, 22)
        let translation = dragTranslation
        withAnimation(tabSpring) {
            dragTranslation = 0
            if translation <= -threshold {
                shiftTab(by: 1)
            } else if translation >= threshold {
                shiftTab(by: -1)
            }
            syncPageScroll()
        }
    }

    @ViewBuilder
    private func page(for tab: IslandTab) -> some View {
        switch tab {
        case .media:
            MediaTabView(service: model.nowPlaying)
        case .clipboard:
            ClipboardTabView(service: model.clipboard)
        case .timer:
            TimerTabView(service: model.timer)
        case .counter:
            CounterTabView(service: model.counter)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            tabBar
            Spacer(minLength: 6)
            headerAccessories
        }
    }

    /// Etiketler sabit; cam kapsül sayfa kaydırmasıyla orantılı kayar.
    /// Kapsül her zaman sahnede kalır — ölçüm gecikmesinde kaybolup
    /// göz kırpmasına yol açmasın diye son bilinen kare kullanılır.
    private var tabBar: some View {
        ZStack(alignment: .topLeading) {
            let frame = indicatorFrame

            indicatorCapsule
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .opacity(frame.width > 1 ? 1 : 0)
                .allowsHitTesting(false)

            HStack(spacing: 4) {
                ForEach(IslandTab.allCases) { tab in
                    Button {
                        selectTab(tab)
                    } label: {
                        tabLabel(tab, isActive: model.selectedTab == tab)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(tab.title)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TabFramesKey.self,
                                value: [tab.pageIndex: proxy.frame(in: .named("dynoTabBar"))]
                            )
                        }
                    }
                }
            }
        }
        .coordinateSpace(name: "dynoTabBar")
        .onPreferenceChange(TabFramesKey.self) { frames in
            // Ölçümler yalnızca birikir; hiçbir sekme kaybolmaz.
            tabFrames.merge(frames) { _, new in new }
        }
    }

    /// Aktif kapsülün anlık çerçevesi — sürükleme miktarına göre iki sekme
    /// çerçevesi arasında interpolasyon.
    private var indicatorFrame: CGRect {
        let count = IslandTab.allCases.count
        let raw = CGFloat(model.selectedTab.pageIndex) - dragTranslation / max(pageWidth, 1)
        let clamped = min(max(raw, 0), CGFloat(count - 1))
        let lower = Int(clamped.rounded(.down))
        let upper = min(lower + 1, count - 1)
        let fraction = clamped - CGFloat(lower)

        guard let a = tabFrames[lower], let b = tabFrames[upper] else { return .zero }
        return CGRect(
            x: a.minX + (b.minX - a.minX) * fraction,
            y: a.minY + (b.minY - a.minY) * fraction,
            width: a.width + (b.width - a.width) * fraction,
            height: a.height + (b.height - a.height) * fraction
        )
    }

    @ViewBuilder
    private var indicatorCapsule: some View {
        if #available(macOS 26.0, *) {
            // `interactive()` imleçle tepki verip nabız gibi parlıyordu.
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
                .glassEffect(.regular.tint(Color.white.opacity(0.12)), in: .capsule)
        } else {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.1))
        }
    }

    private func tabLabel(_ tab: IslandTab, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: tab.symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(tab.title)
                .font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.42))
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    @ViewBuilder
    private var headerAccessories: some View {
        if model.selectedTab == .clipboard {
            Text("\(model.clipboard.entries.count)")
                .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 4)
                .accessibilityLabel("\(model.clipboard.entries.count) kopya")

            Button {
                isShowingClearConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        .white.opacity(model.clipboard.entries.isEmpty ? 0.2 : 0.55)
                    )
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.clipboard.entries.isEmpty)
            .help(L10n.clipboardClearHelp)
        }

        if model.isPinned {
            Text(L10n.pinned)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Color.accentColor.opacity(0.9))
        }

        if model.selectedTab.canDockToIsland {
            Button {
                model.dockActivityToIsland()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.collapseToIsland)
        }

        Button {
            model.togglePin()
        } label: {
            Image(systemName: model.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(model.isPinned ? Color.accentColor : .white.opacity(0.55))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(model.isPinned ? L10n.unpin : L10n.pin)

        Button {
            model.openSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.settings)
    }

    private func selectTab(_ tab: IslandTab) {
        guard tab != model.selectedTab else { return }
        withAnimation(tabSpring) {
            dragTranslation = 0
            model.selectedTab = tab
            syncPageScroll()
        }
    }

    private func advanceTab(by delta: Int) {
        withAnimation(tabSpring) {
            dragTranslation = 0
            shiftTab(by: delta)
            syncPageScroll()
        }
    }

    private func shiftTab(by delta: Int) {
        let tabs = IslandTab.allCases
        guard let index = tabs.firstIndex(of: model.selectedTab) else { return }
        let next = index + delta
        guard tabs.indices.contains(next) else { return }
        model.selectedTab = tabs[next]
    }
}

extension IslandTab {
    var pageIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

private struct TabFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Trackpad yatay kaydırmasını parmakla birebir sayfa kaymasına çevirir.
private struct HorizontalTabSwipeCatcher: NSViewRepresentable {
    var isEnabled: Bool
    var onChange: (CGFloat) -> Void
    var onEnd: () -> Void
    var onStep: (Int) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.apply(isEnabled: isEnabled, onChange: onChange, onEnd: onEnd, onStep: onStep)
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.apply(isEnabled: isEnabled, onChange: onChange, onEnd: onEnd, onStep: onStep)
    }

    final class CatcherView: NSView {
        private var isEnabled = false
        private var onChange: ((CGFloat) -> Void)?
        private var onEnd: (() -> Void)?
        private var onStep: ((Int) -> Void)?

        private var monitor: Any?
        private var isTracking = false
        private var lastStepTime: TimeInterval = 0

        func apply(
            isEnabled: Bool,
            onChange: @escaping (CGFloat) -> Void,
            onEnd: @escaping () -> Void,
            onStep: @escaping (Int) -> Void
        ) {
            self.isEnabled = isEnabled
            self.onChange = onChange
            self.onEnd = onEnd
            self.onStep = onStep
            if !isEnabled { isTracking = false }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { start() } else { stop() }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func start() {
            stop()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window === window else {
                    return event
                }
                return self.handle(event) ? nil : event
            }
        }

        private func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            isTracking = false
        }

        private func handle(_ event: NSEvent) -> Bool {
            // Panel kapalıyken geniş yerleşim sahnede ama görünmez; kaydırma
            // olayları o haldeyken yutulmamalı.
            guard isEnabled else { return false }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            switch event.phase {
            case .began:
                isTracking = abs(dx) >= abs(dy)
                return isTracking
            case .changed:
                if !isTracking {
                    // Yatay baskınlaşırsa gesture ortasında da devral.
                    guard abs(dx) > abs(dy) * 1.1, abs(dx) > 0.6 else { return false }
                    isTracking = true
                }
                onChange?(dx)
                return true
            case .ended, .cancelled:
                guard isTracking else { return false }
                isTracking = false
                onEnd?()
                return true
            default:
                break
            }

            // Momentum: sürükleme bittikten sonra gelen kuyruk yutulur.
            if event.momentumPhase != [] {
                return isTracking
            }

            // Klasik tekerlek / kesikli yatay kaydırma.
            guard abs(dx) > abs(dy) * 1.1, abs(dx) > 0.6 else { return false }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastStepTime > 0.3 else { return true }
            lastStepTime = now
            onStep?(dx < 0 ? 1 : -1)
            return true
        }
    }
}
