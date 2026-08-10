import SwiftUI

/// Dynamic Island ses çubukları — çalarken organik; durunca smooth noktalara iner.
struct VoiceChartsView: View {
    var isAnimating: Bool
    var color: Color = Color(red: 0.82, green: 0.68, blue: 0.48)

    private let barCount = 4
    private let barWidth: CGFloat = 2.5
    private let spacing: CGFloat = 2.4
    private let maxHeight: CGFloat = 13
    private let dotSize: CGFloat = 2.5
    private let collapseDuration: TimeInterval = 0.48

    @State private var pausedAt: Date?
    @State private var frozenHeights: [CGFloat] = Array(repeating: 8, count: 4)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: shouldPauseTimeline)) { context in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(color.opacity(isAnimating ? 1 : 0.85))
                        .frame(
                            width: barWidth,
                            height: displayHeight(index: index, date: context.date)
                        )
                        .frame(width: barWidth, height: maxHeight, alignment: .center)
                }
            }
            .frame(
                width: CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing,
                height: maxHeight
            )
        }
        .onChange(of: isAnimating) { _, animating in
            if animating {
                pausedAt = nil
            } else {
                let now = Date()
                frozenHeights = (0..<barCount).map { liveHeight(index: $0, date: now) }
                pausedAt = now
            }
        }
    }

    private var shouldPauseTimeline: Bool {
        if isAnimating { return false }
        guard let pausedAt else { return true }
        return Date().timeIntervalSince(pausedAt) > collapseDuration + 0.05
    }

    private func displayHeight(index: Int, date: Date) -> CGFloat {
        if isAnimating {
            return liveHeight(index: index, date: date)
        }
        guard let pausedAt else { return dotSize }
        let raw = min(1, max(0, date.timeIntervalSince(pausedAt) / collapseDuration))
        let eased = 1 - pow(1 - raw, 3)
        let from = frozenHeights.indices.contains(index) ? frozenHeights[index] : maxHeight * 0.5
        return max(dotSize, from + (dotSize - from) * eased)
    }

    private func liveHeight(index: Int, date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
        let i = Double(index)
        let envelope = 0.55 + 0.45 * sin(t * 2.1 + i * 0.9)
        let pulse = 0.5 + 0.5 * sin(t * 7.4 + i * 1.35)
        let spark = 0.5 + 0.5 * sin(t * 13.8 + i * 2.1)
        let chatter = 0.5 + 0.5 * sin(t * 19.2 + i * 0.55)
        let mixed = envelope * (0.45 * pulse + 0.30 * spark + 0.25 * chatter)
        let beat = max(0, sin(t * 3.35 + i * 0.4))
        let transient = pow(beat, 8) * 0.35
        let level = min(1, mixed * 0.85 + transient + 0.12)
        return max(3.5, maxHeight * level)
    }
}

/// Yalnızca ada durumunda görünen parçalar: ses dalgası, aşağı ok ve
/// genişletme dokunuş alanı. Panel büyürken sönerler.
struct IslandAccentLayer: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var media: NowPlayingService
    let panelSize: CGSize
    let progress: CGFloat

    private var collapsed: CGSize {
        model.collapsedPanelSize
    }

    /// Açılış animasyonu: parçalar çentik merkezinden yanlara açılır.
    private var launch: CGFloat {
        1 - min(1, max(0, model.launchReveal))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { model.expandImmediately() }
                .accessibilityLabel(L10n.expandIsland)

            if model.selectedTab == .media {
                VoiceChartsView(isAnimating: media.snapshot.isPlaying && media.snapshot.hasMedia)
                    .position(x: trailingCenterX(itemWidth: 18, inset: 11), y: collapsed.height / 2)
            }

            if model.isActivityDocked {
                expandChevron
                    .position(x: trailingCenterX(itemWidth: 20, inset: 6), y: collapsed.height / 2)
            }
        }
        .frame(width: panelSize.width, height: panelSize.height, alignment: .topLeading)
    }

    private func trailingCenterX(itemWidth: CGFloat, inset: CGFloat) -> CGFloat {
        let islandCenter = panelSize.width / 2 + collapsed.width / 2 - inset - itemWidth / 2
        // Açılışta merkezden dışarı doğru kayar.
        return islandCenter + (panelSize.width / 2 - islandCenter) * launch
    }

    private var expandChevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.65))
            .frame(width: 20, height: 22)
            .background(Circle().fill(Color.white.opacity(0.08)))
            .allowsHitTesting(false)
            .accessibilityLabel(L10n.expand)
    }
}

/// Ada ile geniş panel arasında büyüyüp küçülen gerçek öğeler.
struct IslandMorphLayer: View {
    @EnvironmentObject private var model: AppModel
    /// Nested `ObservableObject` — `AppModel` üzerinden izlenmez; ada
    /// durumundaki play/+ güncellemeleri için ayrı gözlem şart.
    @ObservedObject var timer: TimerService
    @ObservedObject var counter: CounterService
    let panelSize: CGSize

    /// macOS Space Black — siyah ada üzerinde hafif ayrışır.
    private static let spaceBlack = Color(red: 0.17, green: 0.17, blue: 0.18)

    private var collapsed: CGSize {
        model.collapsedPanelSize
    }

    /// Ada kilitliyken sağdaki aşağı ok kadar ekstra boşluk.
    private var trailingInset: CGFloat {
        model.isActivityDocked ? 31 : 6
    }

    /// Açılış animasyonu: öğeler çentik merkezinden yanlara açılır.
    private var launchShift: CGFloat {
        1 - min(1, max(0, model.launchReveal))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Üç sekmenin öğeleri de sahnede durur: sayfalar kayarken kendi
            // sayfalarıyla birlikte hareket eder, sayfa alanının dışına
            // çıkınca maske tarafından kırpılırlar.
            artworkElement
            timerElements
            counterElements
        }
        .frame(width: panelSize.width, height: panelSize.height, alignment: .topLeading)
        .mask {
            Rectangle()
                .frame(width: maskRect.width, height: maskRect.height)
                .position(x: maskRect.midX, y: maskRect.midY)
        }
        // Medya/pano sayfalarında katman tıklamaları yutmasın — seek, ±10,
        // ileri/geri ExpandedIslandView'da. Timer/Sayaç ve ada durumunda
        // yalnızca o zaman hit-test açık.
        .allowsHitTesting(morphHitsEnabled)
    }

    private var morphHitsEnabled: Bool {
        let progress = min(1, max(0, model.morphProgress))
        if progress < 0.05 { return true }
        guard progress > 0.5 else { return false }
        return model.selectedTab == .timer || model.selectedTab == .counter
    }

    /// Ada durumunda tüm panel, açıkken sayfa alanı. Aradaki karelerde
    /// interpolasyon: öğeler adaya giderken sayfa sınırına takılmaz.
    private var maskRect: CGRect {
        let progress = min(1, max(0, model.morphProgress))
        let full = CGRect(origin: .zero, size: panelSize)
        guard let pages = model.morphTargets[.pagesArea], pages.size.width > 1 else {
            return full
        }
        let target = CGRect(
            x: panelSize.width / 2 + pages.centerOffsetX - pages.size.width / 2 - 4,
            y: pages.centerY - pages.size.height / 2 - 4,
            width: pages.size.width + 8,
            height: pages.size.height + 8
        )
        return CGRect(
            x: full.minX + (target.minX - full.minX) * progress,
            y: full.minY + (target.minY - full.minY) * progress,
            width: full.width + (target.width - full.width) * progress,
            height: full.height + (target.height - full.height) * progress
        )
    }

    private var artworkElement: some View {
        MorphElement(
            anchor: .mediaArtwork,
            edge: .leading,
            // Dikey pad ile aynı (~2.5): hapın iç eğrisine oturur.
            inset: 2.5,
            fixedIslandSize: CGSize(width: 28, height: 28),
            panelSize: panelSize,
            collapsedSize: collapsed,
            tab: .media
        ) { metrics in
            MorphingArtwork(media: model.nowPlaying, metrics: metrics)
        }
        .offset(x: launchOffset(forLeadingWidth: 28))
    }

    @ViewBuilder
    private var timerElements: some View {
        MorphElement(
            anchor: .timerDisplay,
            edge: .leading,
            inset: 10,
            panelSize: panelSize,
            collapsedSize: collapsed,
            tab: .timer
        ) { metrics in
            Text(timer.displayString)
                .font(.system(size: metrics.lerp(12, 42), weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .fixedSize()
        }

        MorphElement(
            anchor: .timerToggle,
            edge: .trailing,
            inset: trailingInset,
            fixedIslandSize: CGSize(width: 22, height: 22),
            panelSize: panelSize,
            collapsedSize: collapsed,
            tab: .timer
        ) { metrics in
            // Ada ve panelde aynı stil — büyürken renk değişmez.
            Button {
                timer.toggle()
            } label: {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: metrics.lerp(9.5, 18), weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: metrics.size.width, height: metrics.size.height)
                    .background(Circle().fill(.white))
            }
            .buttonStyle(.plain)
            .help(timer.isRunning ? L10n.stop : L10n.start)
        }
    }

    @ViewBuilder
    private var counterElements: some View {
        MorphElement(
            anchor: .counterValue,
            edge: .leading,
            inset: 10,
            panelSize: panelSize,
            collapsedSize: collapsed,
            tab: .counter
        ) { metrics in
            Text("\(counter.count)")
                .font(.system(size: metrics.lerp(13, 40), weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: counter.countsDown))
                .animation(.snappy(duration: 0.32), value: counter.count)
                .fixedSize()
        }

        MorphElement(
            anchor: .counterPlus,
            edge: .trailing,
            inset: trailingInset,
            fixedIslandSize: CGSize(width: 22, height: 22),
            panelSize: panelSize,
            collapsedSize: collapsed,
            tab: .counter
        ) { metrics in
            Button {
                withAnimation(.snappy(duration: 0.32)) {
                    counter.increment()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: metrics.lerp(9.5, 18), weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: metrics.size.width, height: metrics.size.height)
                    .background(
                        Circle()
                            .fill(Self.spaceBlack)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                            }
                    )
            }
            .buttonStyle(.plain)
            .help(L10n.counterPlusHelp)
        }
    }

    /// Ada içeriği açılışta çentik merkezinden yanlara doğru açılır.
    private func launchOffset(forLeadingWidth width: CGFloat) -> CGFloat {
        let islandCenter = panelSize.width / 2 - collapsed.width / 2 + 2.5 + width / 2
        return (panelSize.width / 2 - islandCenter) * launchShift
    }
}

private struct MorphingArtwork: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var media: NowPlayingService
    let metrics: MorphMetrics

    /// Ada hapının iç eğrisi — dış yarıçap − yatay inset.
    private var islandLeadingRadius: CGFloat {
        max(model.islandCornerRadius - 2.5, metrics.size.height * 0.5)
    }

    private var leadingRadius: CGFloat {
        metrics.lerp(islandLeadingRadius, 12)
    }

    private var trailingRadius: CGFloat {
        metrics.lerp(6.5, 12)
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: leadingRadius,
            bottomLeadingRadius: leadingRadius,
            bottomTrailingRadius: trailingRadius,
            topTrailingRadius: trailingRadius,
            style: .continuous
        )
    }

    var body: some View {
        ZStack {
            shape.fill(Color.white.opacity(0.08))

            if let artwork = media.snapshot.artwork {
                SharpArtworkView(image: artwork, cornerRadius: 0)
                    .clipShape(shape)
            } else if let icon = media.snapshot.applicationIcon {
                SharpArtworkView(image: icon, cornerRadius: 0)
                    .clipShape(shape)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: metrics.lerp(11, 28), weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6)
        }
    }
}
