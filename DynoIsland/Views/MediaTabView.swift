import AppKit
import SwiftUI

struct MediaTabView: View {
    @ObservedObject var service: NowPlayingService
    @ObservedObject private var prefs = PreferencesStore.shared

    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        Group {
            if service.snapshot.hasMedia {
                standardPlayer
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id(prefs.preferences.languageCode)
        .onChange(of: service.snapshot.elapsed) { _, newValue in
            if !isScrubbing {
                scrubValue = newValue
            }
        }
        .onAppear {
            scrubValue = service.snapshot.elapsed
        }
    }

    private var standardPlayer: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 14
            // Geniş yerleşimde 16:9; adadaki kare kapaktan animasyonla büyür.
            let artWidth: CGFloat = 160
            let artHeight: CGFloat = 90

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: gap) {
                    // Kapağın kendisi morph katmanında çizilir; burada yalnızca
                    // yerini tutar.
                    Color.clear
                        .frame(width: artWidth, height: artHeight)
                        .morphSlot(.mediaArtwork)

                    metaAndControls
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minWidth: 0)
                }

                seekControls
                    .frame(maxWidth: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private var metaAndControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if let icon = service.snapshot.applicationIcon {
                    SharpArtworkView(image: icon, cornerRadius: 3)
                        .frame(width: 13, height: 13)
                }
                Text(service.snapshot.applicationName.isEmpty ? L10n.tabNowPlaying : service.snapshot.applicationName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Text(service.snapshot.title.isEmpty ? L10n.unknownTitle : service.snapshot.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(.top, 6)

            Text(secondaryLine)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .padding(.top, 3)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                controlButton("backward.fill", help: L10n.previousTrack) {
                    service.send(.previousTrack)
                }

                Button {
                    service.send(.togglePlayPause)
                } label: {
                    Image(systemName: service.snapshot.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(.plain)
                .help(service.snapshot.isPlaying ? L10n.pause : L10n.play)

                controlButton("forward.fill", help: L10n.nextTrack) {
                    service.send(.nextTrack)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var seekControls: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : service.snapshot.elapsed },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(service.snapshot.duration, 0.001),
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing {
                        service.seek(to: scrubValue)
                    }
                }
            )
            .controlSize(.small)
            .tint(Color.accentColor)
            .disabled(service.snapshot.duration <= 0)

            HStack(spacing: 10) {
                Text(clock(isScrubbing ? scrubValue : service.snapshot.elapsed))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(minWidth: 40, alignment: .leading)

                skipChip("−10s", help: L10n.skipBack10) {
                    service.skip(by: -10)
                }

                skipChip("+10s", help: L10n.skipForward10) {
                    service.skip(by: 10)
                }

                Spacer(minLength: 0)

                Text(clock(service.snapshot.duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
    }

    private var secondaryLine: String {
        if !service.snapshot.artist.isEmpty { return service.snapshot.artist }
        if !service.snapshot.album.isEmpty { return service.snapshot.album }
        return " "
    }

    private func controlButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func skipChip(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .help(help)
        .disabled(service.snapshot.duration <= 0)
        .opacity(service.snapshot.duration <= 0 ? 0.4 : 1)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "music.note.list")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text(L10n.noMediaTitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
            Text(
                service.isSystemSourceAvailable
                    ? L10n.noMediaHint
                    : L10n.noMediaUnavailable
            )
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func clock(_ value: TimeInterval) -> String {
        guard value.isFinite, value > 0 else { return "0:00" }
        let total = Int(value)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
