import AppKit

/// Özel bir CGS "space" — içindeki pencereler Space geçişlerine katılmaz.
///
/// `canJoinAllSpaces` + `stationary` tek başına yetmiyor: macOS paneli eski
/// masaüstüyle birlikte kaydırabiliyor. Pencereyi mutlak seviyesi en yüksek
/// olan kendi space'imize her seferinde (güncel windowNumber ile) ekleyince
/// ada çentikte sabit kalıyor. (Aynı yaklaşım boring.notch'ta da var.)
final class NotchSpace {
    static let shared = NotchSpace()

    private let identifier: CGSSpaceID
    private let spaceIDs: NSArray

    private init() {
        // 1 olmalı; 0 verilirse Finder bu space'e masaüstü simgelerini çiziyor.
        identifier = CGSSpaceCreate(_CGSDefaultConnection(), 1, nil)
        CGSSpaceSetAbsoluteLevel(_CGSDefaultConnection(), identifier, 2_147_483_647)
        spaceIDs = [NSNumber(value: identifier)]
        CGSShowSpaces(_CGSDefaultConnection(), spaceIDs)
    }

    /// windowNumber orderOut/orderFront sonrası değişebilir; her seferinde ekle.
    func attach(_ window: NSWindow) {
        let number = window.windowNumber
        guard number > 0 else { return }
        CGSAddWindowsToSpaces(
            _CGSDefaultConnection(),
            [NSNumber(value: number)],
            spaceIDs
        )
    }

    func detach(_ window: NSWindow) {
        let number = window.windowNumber
        guard number > 0 else { return }
        CGSRemoveWindowsFromSpaces(
            _CGSDefaultConnection(),
            [NSNumber(value: number)],
            spaceIDs
        )
    }

    func tearDown() {
        CGSHideSpaces(_CGSDefaultConnection(), spaceIDs)
        CGSSpaceDestroy(_CGSDefaultConnection(), identifier)
    }
}

private typealias CGSConnectionID = UInt
private typealias CGSSpaceID = UInt64

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(
    _ cid: CGSConnectionID,
    _ unknown: Int,
    _ options: NSDictionary?
) -> CGSSpaceID

@_silgen_name("CGSSpaceDestroy")
private func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)

@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int)

@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: NSArray, _ spaces: NSArray)

@_silgen_name("CGSRemoveWindowsFromSpaces")
private func CGSRemoveWindowsFromSpaces(
    _ cid: CGSConnectionID,
    _ windows: NSArray,
    _ spaces: NSArray
)

@_silgen_name("CGSHideSpaces")
private func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)

@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: NSArray)
