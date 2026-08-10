import AppKit
import Foundation

struct ClipboardEntry: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case link
        case image
        case files

        var symbol: String {
            switch self {
            case .text: "text.alignleft"
            case .link: "link"
            case .image: "photo"
            case .files: "doc.on.doc"
            }
        }

        var label: String {
            switch self {
            case .text: "Metin"
            case .link: "Bağlantı"
            case .image: "Görsel"
            case .files: "Dosya"
            }
        }
    }

    let id: UUID
    let createdAt: Date
    let kind: Kind
    let title: String
    let detail: String
    let text: String?
    let filePaths: [String]
    let imageData: Data?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: Kind,
        title: String,
        detail: String = "",
        text: String? = nil,
        filePaths: [String] = [],
        imageData: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.title = title
        self.detail = detail
        self.text = text
        self.filePaths = filePaths
        self.imageData = imageData
    }

    var image: NSImage? {
        imageData.flatMap(NSImage.init(data:))
    }

    var contentSignature: String {
        switch kind {
        case .text, .link:
            return "\(kind.rawValue):\(text ?? "")"
        case .files:
            return "files:\(filePaths.joined(separator: "|"))"
        case .image:
            let prefix = imageData?.prefix(128).base64EncodedString() ?? ""
            return "image:\(imageData?.count ?? 0):\(prefix)"
        }
    }
}
