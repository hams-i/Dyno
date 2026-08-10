import AppKit
import Foundation

struct NowPlayingSnapshot {
    var title: String
    var artist: String
    var album: String
    var artwork: NSImage?
    var applicationIcon: NSImage?
    var applicationName: String
    var bundleIdentifier: String?
    var duration: TimeInterval
    var elapsed: TimeInterval
    var isPlaying: Bool

    static let empty = NowPlayingSnapshot(
        title: "",
        artist: "",
        album: "",
        artwork: nil,
        applicationIcon: nil,
        applicationName: "",
        bundleIdentifier: nil,
        duration: 0,
        elapsed: 0,
        isPlaying: false
    )

    var hasMedia: Bool {
        !title.isEmpty || !artist.isEmpty || artwork != nil
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }
}
