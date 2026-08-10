import AppKit
import Foundation

/// macOS 15.4+ MediaRemote'u doğrudan engellediği için
/// `/usr/bin/perl` + MediaRemote Adapter üzerinden “Şimdi Çalıyor” okur.
@MainActor
final class NowPlayingService: ObservableObject {
    enum Command: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    @Published private(set) var snapshot = NowPlayingSnapshot.empty
    @Published private(set) var isSystemSourceAvailable = true

    var onSourceApplicationChanged: ((String?) -> Void)?

    private var streamProcess: Process?
    private var streamStdout: FileHandle?
    private var streamBuffer = Data()
    private var artworkRefreshTask: Task<Void, Never>?
    private var currentSourceBundleIdentifier: String?
    private var lastArtworkTrackKey: String?
    /// Parça bazlı kapak önbelleği — play/pause flicker olmasın.
    private var artworkCache: [String: NSImage] = [:]
    private var isStarted = false
    /// Seek sonrası stream eski elapsed ile geri yazmasın.
    private var seekLockUntil: Date?
    private var seekLockedElapsed: TimeInterval?

    private lazy var adapterScriptURL: URL? = {
        Bundle.main.url(
            forResource: "mediaremote-adapter",
            withExtension: "pl",
            subdirectory: "MediaRemoteAdapter"
        )
    }()

    private lazy var adapterFrameworkURL: URL? = {
        Bundle.main.resourceURL?
            .appendingPathComponent("MediaRemoteAdapter/MediaRemoteAdapter.framework")
    }()

    func start() {
        guard !isStarted else { return }
        isStarted = true

        guard adapterScriptURL != nil, adapterFrameworkURL != nil else {
            isSystemSourceAvailable = false
            return
        }

        isSystemSourceAvailable = true
        startStream()
        // İlk kare + kapak için bir kerelik get.
        Task { await refreshOnce(includeArtwork: true) }
    }

    func stop() {
        isStarted = false
        artworkRefreshTask?.cancel()
        artworkRefreshTask = nil
        stopStream()
    }

    func send(_ command: Command) {
        Task {
            // MediaRemote + sistem medya tuşu: YouTube/Chrome next-prev
            // çoğu zaman yalnızca HID medya tuşuna yanıt veriyor.
            switch command {
            case .nextTrack:
                Self.postSystemMediaKey(.next)
            case .previousTrack:
                Self.postSystemMediaKey(.previous)
            case .togglePlayPause:
                break
            case .play, .pause:
                break
            }
            _ = await runAdapter(arguments: ["send", "\(command.rawValue)"])
            try? await Task.sleep(nanoseconds: 220_000_000)
            await refreshOnce(includeArtwork: true)
        }
    }

    /// Timeline konumu (saniye).
    func seek(to elapsedSeconds: TimeInterval) {
        let clamped = max(0, min(elapsedSeconds, max(snapshot.duration, 0)))
        let micros = Int64((clamped * 1_000_000).rounded())
        // Optimistic UI + kısa kilit — stream eski değeri yazıp flicker yapmasın.
        var next = snapshot
        next.elapsed = clamped
        snapshot = next
        seekLockedElapsed = clamped
        seekLockUntil = Date().addingTimeInterval(0.9)
        Task {
            _ = await runAdapter(arguments: ["seek", "\(micros)"])
            // Hemen get çekme — henüz güncellenmemiş elapsed flicker yaratır.
        }
    }

    func skip(by deltaSeconds: TimeInterval) {
        seek(to: snapshot.elapsed + deltaSeconds)
    }

    private enum SystemMediaKey: Int32 {
        case next = 17      // NX_KEYTYPE_NEXT
        case previous = 18  // NX_KEYTYPE_PREVIOUS
    }

    private static func postSystemMediaKey(_ key: SystemMediaKey) {
        func post(down: Bool) {
            let keyFlags: NSEvent.ModifierFlags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = Int((key.rawValue << 16) | ((down ? 0xA : 0xB) << 8))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: keyFlags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ), let cgEvent = event.cgEvent else { return }
            cgEvent.post(tap: .cghidEventTap)
        }
        post(down: true)
        post(down: false)
    }

    private func startStream() {
        stopStream()

        guard let process = makeAdapterProcess(
            arguments: ["stream", "--no-diff", "--no-artwork", "--debounce=180"]
        ) else {
            isSystemSourceAvailable = false
            return
        }

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        streamStdout = stdout.fileHandleForReading
        streamProcess = process

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            Task { @MainActor in
                self?.consumeStreamData(chunk)
            }
        }

        process.terminationHandler = { [weak self] finished in
            Task { @MainActor in
                guard let self, self.isStarted else { return }
                // Beklenmedik çıkışta bir süre sonra yeniden dene.
                if finished.terminationStatus != 0 || self.streamProcess === finished {
                    self.streamProcess = nil
                    self.streamStdout?.readabilityHandler = nil
                    self.streamStdout = nil
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    if self.isStarted, self.streamProcess == nil {
                        self.startStream()
                    }
                }
            }
        }

        do {
            try process.run()
        } catch {
            isSystemSourceAvailable = false
            stopStream()
        }
    }

    private func stopStream() {
        streamStdout?.readabilityHandler = nil
        streamStdout = nil
        if let streamProcess, streamProcess.isRunning {
            streamProcess.terminationHandler = nil
            streamProcess.terminate()
        }
        streamProcess = nil
        streamBuffer.removeAll(keepingCapacity: false)
    }

    private func consumeStreamData(_ chunk: Data) {
        if chunk.isEmpty {
            return
        }
        streamBuffer.append(chunk)

        while let newline = streamBuffer.firstIndex(of: 0x0A) {
            let lineData = streamBuffer.subdata(in: streamBuffer.startIndex..<newline)
            let next = streamBuffer.index(after: newline)
            streamBuffer.removeSubrange(streamBuffer.startIndex..<next)
            guard !lineData.isEmpty,
                  let line = String(data: lineData, encoding: .utf8) else {
                continue
            }
            handleStreamLine(line)
        }
    }

    private func handleStreamLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["payload"] as? [String: Any] else {
            return
        }

        applyPayload(payload, preserveArtwork: true)
    }

    private func refreshOnce(includeArtwork: Bool) async {
        var arguments = ["get"]
        if !includeArtwork {
            arguments.append("--no-artwork")
        }
        arguments.append("--now")

        guard let output = await runAdapter(arguments: arguments),
              let data = output.data(using: .utf8) else {
            return
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "null" || trimmed.isEmpty {
            applyPayload([:], preserveArtwork: false)
            return
        }

        guard let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any] else {
            return
        }
        // Artwork istenmediyse mevcut kapağı asla silme.
        applyPayload(payload, preserveArtwork: !includeArtwork)
    }

    private func applyPayload(_ payload: [String: Any], preserveArtwork: Bool) {
        let title = stringValue(payload["title"]) ?? ""
        if title.isEmpty && stringValue(payload["bundleIdentifier"]) == nil {
            if snapshot.hasMedia {
                snapshot = .empty
                currentSourceBundleIdentifier = nil
                lastArtworkTrackKey = nil
                onSourceApplicationChanged?(nil)
            }
            return
        }

        let artist = stringValue(payload["artist"]) ?? ""
        let album = stringValue(payload["album"]) ?? ""
        let bundleIdentifier = stringValue(payload["bundleIdentifier"])
        let duration = doubleValue(payload["duration"])
            ?? microsToSeconds(payload["durationMicros"])
            ?? 0
        var elapsed = doubleValue(payload["elapsedTimeNow"])
            ?? doubleValue(payload["elapsedTime"])
            ?? microsToSeconds(payload["elapsedTimeNowMicros"])
            ?? microsToSeconds(payload["elapsedTimeMicros"])
            ?? 0
        if let until = seekLockUntil, Date() < until, let locked = seekLockedElapsed {
            if abs(elapsed - locked) < 1.25 {
                seekLockUntil = nil
                seekLockedElapsed = nil
            } else {
                elapsed = locked
            }
        } else if seekLockUntil != nil {
            seekLockUntil = nil
            seekLockedElapsed = nil
        }
        let playbackRate = doubleValue(payload["playbackRate"]) ?? 0
        let playing = boolValue(payload["playing"]) ?? (playbackRate > 0)
        let key = trackKey(title: title, artist: artist, bundle: bundleIdentifier)
        let trackChanged = key != lastArtworkTrackKey

        // Her zaman önce cache / mevcut kapak — boşluk flicker’ı yok.
        var artwork = artworkCache[key] ?? (trackChanged ? nil : snapshot.artwork)
        if preserveArtwork, artwork == nil {
            artwork = snapshot.artwork
        }

        if let artworkData = decodeArtwork(payload["artworkData"]),
           let decoded = Self.sharpImage(from: artworkData) {
            let incomingPixels = ArtworkImageFactory.pixelCount(of: decoded)
            let existingPixels = ArtworkImageFactory.pixelCount(of: artwork)
            if artwork == nil || incomingPixels >= existingPixels {
                artwork = decoded
                artworkCache[key] = decoded
            }
            lastArtworkTrackKey = key
        } else {
            if let artwork {
                artworkCache[key] = artwork
            }
            if lastArtworkTrackKey == nil || !trackChanged || artwork != nil {
                lastArtworkTrackKey = key
            }
        }

        let application = applicationDetails(bundleIdentifier: bundleIdentifier)
        snapshot = NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            artwork: artwork,
            applicationIcon: application.icon,
            applicationName: application.name,
            bundleIdentifier: bundleIdentifier,
            duration: duration,
            elapsed: elapsed,
            isPlaying: playing
        )

        if bundleIdentifier != currentSourceBundleIdentifier {
            currentSourceBundleIdentifier = bundleIdentifier
            onSourceApplicationChanged?(bundleIdentifier)
        }

        if snapshot.hasMedia {
            let pixels = ArtworkImageFactory.pixelCount(of: artwork)
            // YouTube / tarayıcı kapakları MediaRemote’da gecikmeli veya boş gelebilir.
            let isBrowser = (bundleIdentifier ?? "").contains("chrome")
                || (bundleIdentifier ?? "").contains("firefox")
                || (bundleIdentifier ?? "").contains("Safari")
                || (bundleIdentifier ?? "").contains("browser")
                || (bundleIdentifier ?? "").contains("youtube")
            if artwork == nil || (trackChanged && pixels < 40_000) || pixels < 40_000 || (isBrowser && pixels < 80_000) {
                scheduleArtworkRefresh(aggressive: isBrowser || artwork == nil)
            }
        }
    }

    private func scheduleArtworkRefresh(aggressive: Bool = false) {
        artworkRefreshTask?.cancel()
        artworkRefreshTask = Task { [weak self] in
            let delays: [UInt64] = aggressive
                ? [120_000_000, 350_000_000, 800_000_000, 1_600_000_000, 3_000_000_000]
                : [250_000_000, 700_000_000, 1_500_000_000]
            for delay in delays {
                try? await Task.sleep(nanoseconds: delay)
                guard let self, !Task.isCancelled else { return }
                await self.refreshOnce(includeArtwork: true)
                let pixels = ArtworkImageFactory.pixelCount(of: self.snapshot.artwork)
                if self.snapshot.artwork != nil, pixels >= 40_000 {
                    return
                }
                if !self.snapshot.hasMedia {
                    return
                }
            }
        }
    }

    private func runAdapter(arguments: [String]) async -> String? {
        guard let process = makeAdapterProcess(arguments: arguments) else {
            return nil
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return nil
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: text)
            }
        }
    }

    private func makeAdapterProcess(arguments: [String]) -> Process? {
        guard let script = adapterScriptURL?.path,
              let framework = adapterFrameworkURL?.path,
              FileManager.default.fileExists(atPath: script),
              FileManager.default.fileExists(atPath: framework) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script, framework] + arguments
        process.qualityOfService = .userInitiated
        return process
    }

    private func trackKey(title: String, artist: String, bundle: String?) -> String {
        "\(bundle ?? "")|\(title)|\(artist)"
    }

    private func stringValue(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty { return value }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }

    private func microsToSeconds(_ value: Any?) -> Double? {
        guard let micros = doubleValue(value) else { return nil }
        return micros / 1_000_000
    }

    private func decodeArtwork(_ value: Any?) -> Data? {
        guard let base64 = value as? String, !base64.isEmpty else { return nil }
        return Data(base64Encoded: base64)
    }

    private static func sharpImage(from data: Data) -> NSImage? {
        ArtworkImageFactory.make(from: data)
    }

    private func applicationDetails(bundleIdentifier: String?) -> (name: String, icon: NSImage?) {
        guard let bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
              ) else {
            return ("", nil)
        }

        let name = Bundle(url: appURL)?.object(
            forInfoDictionaryKey: "CFBundleDisplayName"
        ) as? String
            ?? Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        // Uygulama ikonu: en büyük temsili kullan.
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 512, height: 512)
        return (name, icon)
    }
}
