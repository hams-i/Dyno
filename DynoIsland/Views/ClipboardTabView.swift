import SwiftUI

struct ClipboardTabView: View {
    @ObservedObject var service: ClipboardHistoryService
    @ObservedObject private var prefs = PreferencesStore.shared

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10, alignment: .top),
        GridItem(.flexible(minimum: 0), spacing: 10, alignment: .top),
        GridItem(.flexible(minimum: 0), spacing: 10, alignment: .top)
    ]

    var body: some View {
        Group {
            if service.entries.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
                        ForEach(service.entries) { entry in
                            ClipboardCard(
                                entry: entry,
                                isCopied: service.recentlyCopiedID == entry.id,
                                onCopy: { service.copy(entry) },
                                onDelete: { service.delete(entry) }
                            )
                        }
                    }
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.visible, axes: .vertical)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .id(prefs.preferences.languageCode)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.32))
            Text(L10n.clipboardEmptyTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Text(L10n.clipboardEmptyHint)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.36))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardCard: View {
    let entry: ClipboardEntry
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private let cardHeight: CGFloat = 88
    private let textBlockHeight: CGFloat = 58

    var body: some View {
        Button(action: onCopy) {
            ZStack {
                cardBody
                    .opacity(isCopied ? 0.18 : 1)

                if isCopied {
                    Text("Kopyalandı")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.09) : Color.white.opacity(0.045))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(isHovering ? 0.14 : 0.06), lineWidth: 0.6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: cardHeight + 20)
        .clipped()
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Yeniden kopyala", systemImage: "doc.on.doc", action: onCopy)
            Divider()
            Button("Geçmişten sil", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .help(L10n.copyToClipboard)
    }

    @ViewBuilder
    private var cardBody: some View {
        if entry.kind == .image, let image = entry.image {
            Color.clear
                .overlay {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                }
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(displayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: textBlockHeight, maxHeight: textBlockHeight, alignment: .topLeading)

                Spacer(minLength: 0)

                Text(statsLabel)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
    }

    private var displayText: String {
        let raw = entry.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty { return raw }
        if !entry.title.isEmpty { return entry.title }
        return entry.detail
    }

    private var statsLabel: String {
        let source = displayText
        let characters = source.count
        let words = wordCount(in: source)
        return "\(words) kelime · \(characters) harf"
    }

    private func wordCount(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.split { $0.isWhitespace || $0.isNewline }.count
    }
}
