import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ClipboardHistoryService: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var recentlyCopiedID: UUID?
    @Published var isMonitoring = true

    private let pasteboard = NSPasteboard.general
    private let maximumEntryCount = 48
    private var timer: Timer?
    private var lastChangeCount = 0
    private var feedbackWorkItem: DispatchWorkItem?

    func start() {
        guard timer == nil else { return }

        loadHistory()
        lastChangeCount = pasteboard.changeCount
        captureCurrentContents()

        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        feedbackWorkItem?.cancel()
        saveHistory()
    }

    func copy(_ entry: ClipboardEntry) {
        pasteboard.clearContents()

        switch entry.kind {
        case .text, .link:
            if let text = entry.text {
                pasteboard.setString(text, forType: .string)
            }
        case .files:
            let urls = entry.filePaths.map(URL.init(fileURLWithPath:))
            pasteboard.writeObjects(urls as [NSURL])
        case .image:
            if let image = entry.image {
                pasteboard.writeObjects([image])
            }
        }

        lastChangeCount = pasteboard.changeCount
        showCopiedFeedback(for: entry.id)
    }

    func delete(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        saveHistory()
    }

    func clear() {
        entries.removeAll()
        saveHistory()
    }

    private func pollPasteboard() {
        guard isMonitoring, pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        captureCurrentContents()
    }

    private func captureCurrentContents() {
        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !fileURLs.isEmpty {
            addFileEntry(fileURLs)
            return
        }

        if pasteboard.canReadItem(withDataConformingToTypes: [UTType.image.identifier]),
           let image = NSImage(pasteboard: pasteboard),
           let data = compactImageData(image) {
            let pixelSize = image.representations.first.map { "\($0.pixelsWide) × \($0.pixelsHigh) px" }
                ?? "Görsel"
            add(
                ClipboardEntry(
                    kind: .image,
                    title: L10n.copiedImage,
                    detail: pixelSize,
                    imageData: data
                )
            )
            return
        }

        guard let rawText = pasteboard.string(forType: .string) else { return }
        let text = String(rawText.prefix(50_000))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let isLink = URL(string: trimmed).map { url in
            guard let scheme = url.scheme?.lowercased() else { return false }
            return ["http", "https", "mailto", "ftp"].contains(scheme)
        } ?? false

        let lines = trimmed
            .split(whereSeparator: \Character.isNewline)
            .map(String.init)
        let firstLine = lines.first ?? trimmed
        let title = String(firstLine.prefix(90))
        let detail: String
        if isLink {
            detail = URL(string: trimmed)?.host ?? "Bağlantı"
        } else if lines.count > 1 {
            detail = "\(lines.count) satır · \(trimmed.count) karakter"
        } else {
            detail = "\(trimmed.count) karakter"
        }

        add(
            ClipboardEntry(
                kind: isLink ? .link : .text,
                title: title,
                detail: detail,
                text: text
            )
        )
    }

    private func addFileEntry(_ urls: [URL]) {
        let title: String
        if urls.count == 1 {
            title = urls[0].lastPathComponent
        } else {
            title = L10n.fileCount(urls.count)
        }

        let detail = urls.count == 1
            ? urls[0].deletingLastPathComponent().path
            : urls.prefix(3).map(\.lastPathComponent).joined(separator: ", ")

        add(
            ClipboardEntry(
                kind: .files,
                title: title,
                detail: detail,
                filePaths: urls.map(\.path)
            )
        )
    }

    private func add(_ entry: ClipboardEntry) {
        entries.removeAll { $0.contentSignature == entry.contentSignature }
        entries.insert(entry, at: 0)

        if entries.count > maximumEntryCount {
            entries.removeLast(entries.count - maximumEntryCount)
        }
        saveHistory()
    }

    private func showCopiedFeedback(for id: UUID) {
        feedbackWorkItem?.cancel()
        recentlyCopiedID = id

        let work = DispatchWorkItem { [weak self] in
            guard self?.recentlyCopiedID == id else { return }
            self?.recentlyCopiedID = nil
        }
        feedbackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: work)
    }

    private func compactImageData(_ image: NSImage) -> Data? {
        let maximumDimension: CGFloat = 1_600
        let sourceSize = image.size
        let scale = min(1, maximumDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = NSSize(
            width: max(1, sourceSize.width * scale),
            height: max(1, sourceSize.height * scale)
        )

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .copy,
            fraction: 1
        )
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }

        if let png = bitmap.representation(using: .png, properties: [:]), png.count <= 4_000_000 {
            return png
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.78])
    }

    private var storageURL: URL? {
        DynoDataStore.clipboardURL
    }

    private func loadHistory() {
        guard let url = storageURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else {
            return
        }
        entries = Array(decoded.prefix(maximumEntryCount))
    }

    private func saveHistory() {
        guard let url = storageURL,
              let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
