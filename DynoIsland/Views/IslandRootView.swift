import SwiftUI

// MARK: - Morph altyapısı

/// Ada ile geniş panel arasında büyüyüp küçülen gerçek öğeler.
/// Her öğe hiyerarşide **tek** örnektir; geniş yerleşimde yerini şeffaf bir
/// yuva (`morphSlot`) tutar, öğenin kendisi üst katmanda çizilir.
enum MorphAnchor: Hashable {
    case mediaArtwork
    case clipboardCount
    case tasksCount
    case tasksToggle
    case timerDisplay
    case timerToggle
    case counterValue
    case counterPlus
    /// Sekme sayfalarının görünür alanı — morph öğeleri sayfalarıyla
    /// kayarken bu çerçevenin dışında kırpılır.
    case pagesArea
}

/// Geniş yerleşimdeki hedef. Yatay konum panel merkezine göre saklanır:
/// panel genişledikçe sol kenar kayar, çentik merkezi sabit kalır.
struct MorphTarget: Equatable {
    var centerOffsetX: CGFloat
    var centerY: CGFloat
    var size: CGSize
}

enum MorphSpace {
    static let name = "dynoIslandPanel"
}

private struct MorphTargetKey: PreferenceKey {
    static let defaultValue: [MorphAnchor: MorphTarget] = [:]

    static func reduce(value: inout [MorphAnchor: MorphTarget], nextValue: () -> [MorphAnchor: MorphTarget]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct MorphRecordingKey: EnvironmentKey {
    static let defaultValue = true
}

private struct IslandPanelSizeKey: EnvironmentKey {
    static let defaultValue = CGSize.zero
}

extension EnvironmentValues {
    /// Yalnızca ekranda görünen sekme kendi hedeflerini bildirir.
    var morphRecording: Bool {
        get { self[MorphRecordingKey.self] }
        set { self[MorphRecordingKey.self] = newValue }
    }

    var islandPanelSize: CGSize {
        get { self[IslandPanelSizeKey.self] }
        set { self[IslandPanelSizeKey.self] = newValue }
    }
}

private struct MorphSlotModifier: ViewModifier {
    let anchor: MorphAnchor
    @Environment(\.morphRecording) private var isRecording
    @Environment(\.islandPanelSize) private var panelSize
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(MorphSpace.name))
                Color.clear.preference(
                    key: MorphTargetKey.self,
                    value: measurement(frame)
                )
            }
        }
    }

    /// Yalnızca panel tam boyuttayken ölç — ara karelerde yerleşim sıkışık.
    private func measurement(_ frame: CGRect) -> [MorphAnchor: MorphTarget] {
        guard isRecording,
              model.morphProgress >= 0.98,
              panelSize.width > 1,
              frame.width > 1,
              frame.height > 1 else { return [:] }

        return [anchor: MorphTarget(
            centerOffsetX: frame.midX - panelSize.width / 2,
            centerY: frame.midY,
            size: frame.size
        )]
    }
}

extension View {
    /// Geniş yerleşimde öğenin yerini tutan şeffaf yuva.
    func morphSlot(_ anchor: MorphAnchor) -> some View {
        modifier(MorphSlotModifier(anchor: anchor))
    }
}

/// Öğenin o andaki ara değerleri.
struct MorphMetrics {
    let progress: CGFloat
    /// Ada boyutundan hedefe interpolasyonlu boyut.
    let size: CGSize

    func lerp(_ from: CGFloat, _ to: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    func blend(_ from: Color, _ to: Color) -> Color {
        let a = NSColor(from).usingColorSpace(.sRGB) ?? .white
        let b = NSColor(to).usingColorSpace(.sRGB) ?? .white
        return Color(
            .sRGB,
            red: Double(lerp(a.redComponent, b.redComponent)),
            green: Double(lerp(a.greenComponent, b.greenComponent)),
            blue: Double(lerp(a.blueComponent, b.blueComponent)),
            opacity: Double(lerp(a.alphaComponent, b.alphaComponent))
        )
    }
}

/// Ada ↔ panel arasında yer değiştiren tek örnekli öğe.
struct MorphElement<Content: View>: View {
    let anchor: MorphAnchor
    let edge: HorizontalEdge
    /// Ada kenarından boşluk.
    let inset: CGFloat
    /// Ada boyutu bilinmiyorsa öğe kendi doğal boyutundan ölçülür.
    var fixedIslandSize: CGSize?
    let panelSize: CGSize
    let collapsedSize: CGSize
    /// Öğenin ait olduğu sekme. Sayfalar kaydıkça öğe de birlikte kayar.
    var tab: IslandTab
    @ViewBuilder let content: (MorphMetrics) -> Content

    @EnvironmentObject private var model: AppModel
    @State private var measuredIslandSize: CGSize = .zero

    var body: some View {
        content(metrics)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            captureIslandSize(proxy.size)
                            reportSideRequirement()
                        }
                        .onChange(of: proxy.size) { _, newValue in captureIslandSize(newValue) }
                }
            }
            .onChange(of: islandSize) { _, _ in reportSideRequirement() }
            .position(x: panelSize.width / 2 + centerOffsetX + pageShift, y: centerY)
            .opacity(Double(visibility))
            .allowsHitTesting(isHitEnabled)
    }

    /// Ada: play/+ her zaman; tasks tik yalnızca dock’luyken.
    /// Geniş panel: yalnızca kendi sayfasındayken etkileşimli ankorda.
    private var isHitEnabled: Bool {
        guard visibility > 0.85 else { return false }
        let pageDistance = abs(model.pageScroll - model.restScroll(for: tab))
        guard pageDistance < max(model.pageWidth, 1) * 0.45 else { return false }
        if progress < 0.05 {
            if anchor == .timerToggle || anchor == .counterPlus {
                return true
            }
            return model.isActivityDocked && anchor == .tasksToggle
        }
        guard progress > 0.5 else { return false }
        return anchor == .timerToggle || anchor == .counterPlus
    }

    /// Sayfa kaymasının öğeye yansıyan payı. Ada durumunda (progress 0) öğe
    /// sayfa düzeninden bağımsızdır, bu yüzden pay da sıfırlanır.
    private var pageShift: CGFloat {
        (model.pageScroll - model.restScroll(for: tab)) * progress
    }

    /// Ada: seçili sekmenin morph öğeleri (sol veri + kontroller).
    /// Geniş: sayfa mesafesine göre.
    private var visibility: CGFloat {
        if progress < 0.05 {
            return model.selectedTab == tab ? 1 : 0
        }
        let distance = abs(model.pageScroll - model.restScroll(for: tab)) / max(model.pageWidth, 1)
        return min(1, max(0, 1 - distance))
    }

    private var progress: CGFloat {
        min(1, max(0, model.morphProgress))
    }

    private var target: MorphTarget? {
        model.morphTargets[anchor]
    }

    private var islandSize: CGSize {
        fixedIslandSize ?? measuredIslandSize
    }

    /// Ada boyutu yalnızca dinlenme halinde ölçülür; ara karelerde öğe zaten
    /// büyümüş durumda olur.
    private func captureIslandSize(_ size: CGSize) {
        guard fixedIslandSize == nil, progress <= 0.002 else { return }
        guard size.width > 0.5, size.height > 0.5, size != measuredIslandSize else { return }
        measuredIslandSize = size
    }

    /// Soldaki öğe, çentiğin sol yanındaki kanada sığmalı — yoksa yazının sonu
    /// çentiğin altında kalır.
    private func reportSideRequirement() {
        guard edge == .leading, islandSize.width > 0.5 else { return }
        model.reportIslandLeadingHalfWidth(inset + islandSize.width + 10, for: tab)
    }

    private var metrics: MorphMetrics {
        let island = islandSize
        guard let target else {
            return MorphMetrics(progress: progress, size: island)
        }
        return MorphMetrics(
            progress: progress,
            size: CGSize(
                width: island.width + (target.size.width - island.width) * progress,
                height: island.height + (target.size.height - island.height) * progress
            )
        )
    }

    private var islandCenterOffsetX: CGFloat {
        let half = islandSize.width / 2
        switch edge {
        case .leading:
            return inset + half - collapsedSize.width / 2
        case .trailing:
            return collapsedSize.width / 2 - inset - half
        }
    }

    private var centerOffsetX: CGFloat {
        let from = islandCenterOffsetX
        guard let target else { return from }
        return from + (target.centerOffsetX - from) * progress
    }

    private var centerY: CGFloat {
        let from = collapsedSize.height / 2
        guard let target else { return from }
        return from + (target.centerY - from) * progress
    }
}

// MARK: - Kök görünüm

struct IslandRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let panelSize = proxy.size

            ZStack(alignment: .topLeading) {
                islandBackground

                // Ada'ya özgü parçalar (ses dalgası, aşağı ok) — panel
                // büyüdükçe söner.
                if progress < 0.4 {
                    IslandAccentLayer(
                        media: model.nowPlaying,
                        panelSize: panelSize,
                        progress: progress
                    )
                    .opacity(Double(1 - ramp(0.06, 0.32)))
                    .allowsHitTesting(progress < 0.02)
                }

                // Geniş yerleşim her zaman kendi tam boyutunda kurulu kalır ve
                // büyüyen pencere tarafından maskelenerek açılır. Ara
                // karelerde yeniden yerleşmediği için butonlar/tablar
                // ezilmez. Hiç sökülmediği için de sekme ölçümleri korunur —
                // açılışta gösterge kaybolup göz kırpmaz.
                ExpandedIslandView()
                    .frame(
                        width: model.expandedPanelSize.width,
                        height: model.expandedPanelSize.height,
                        alignment: .top
                    )
                    .scaleEffect(0.94 + 0.06 * ramp(0, 1), anchor: .top)
                    .position(
                        x: panelSize.width / 2,
                        y: model.expandedPanelSize.height / 2
                    )
                    .opacity(Double(ramp(0.14, 0.55)))
                    .allowsHitTesting(progress > 0.9)

                // Tek örnekli öğeler: ada konumundan geniş yerleşimdeki
                // yerlerine kendi boyutlarıyla büyürler.
                IslandMorphLayer(
                    timer: model.timer,
                    counter: model.counter,
                    clipboard: model.clipboard,
                    tasks: model.tasks,
                    panelSize: panelSize
                )
            }
            .frame(width: panelSize.width, height: panelSize.height, alignment: .topLeading)
            .environment(\.islandPanelSize, panelSize)
        }
        .environmentObject(model)
        .coordinateSpace(name: MorphSpace.name)
        .onPreferenceChange(MorphTargetKey.self) { targets in
            // Yayınlanmayan depo: ölçüm yeniden çizim tetiklemesin.
            model.morphTargets.merge(targets) { _, new in new }
        }
        .clipShape(islandShape)
        .contentShape(islandShape)
    }

    private var progress: CGFloat {
        min(1, max(0, model.morphProgress))
    }

    /// İlerlemeyi verilen aralıkta yumuşak 0…1'e eşler.
    private func ramp(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
        let t = min(1, max(0, (progress - start) / (end - start)))
        return t * t * (3 - 2 * t)
    }

    private var bottomRadius: CGFloat {
        let island = model.islandCornerRadius
        return island + (22 - island) * progress
    }

    private var islandShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            // Ada ekran kenarına yaslı — üst köşeler düz.
            topLeadingRadius: 0,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    private var islandBackground: some View {
        islandShape
            .fill(Color.black)
            .overlay {
                islandShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.06 + 0.06 * progress),
                                .white.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.6
                    )
            }
    }
}
