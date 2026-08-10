import AppKit
import Carbon
import Foundation

/// Sistem genelinde Dyno Island aç/kapa — varsayılan: ⌃⌥D
final class HotKeyController {
    static let shared = HotKeyController()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onToggle: (() -> Void)?

    private let hotKeyID = EventHotKeyID(signature: OSType(0x44594E4F), id: 1) // 'DYNO'

    private init() {}

    func start(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        installHandlerIfNeeded()
        registerDefaultHotKey()
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        onToggle = nil
    }

    fileprivate func handleHotKeyPress() {
        let action = onToggle
        DispatchQueue.main.async {
            action?()
        }
    }

    private func registerDefaultHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            dynoHotKeyHandler,
            1,
            &eventType,
            userData,
            &ref
        )
        if status == noErr {
            handlerRef = ref
        }
    }
}

private let dynoHotKeySignature = OSType(0x44594E4F)

private func dynoHotKeyHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let event else { return noErr }

    var hkID = EventHotKeyID()
    let err = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkID
    )
    guard err == noErr, hkID.signature == dynoHotKeySignature, hkID.id == 1 else {
        return noErr
    }

    let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
    controller.handleHotKeyPress()
    return noErr
}
