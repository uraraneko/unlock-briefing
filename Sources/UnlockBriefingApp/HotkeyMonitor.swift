import AppKit
import Carbon

/// Default global toggle: ⌘⇧U (`RegisterEventHotKey`).
final class HotkeyMonitor {
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func registerDefault() {
        unregister()
        let hotKeyID = EventHotKeyID(signature: fourCharCode("UBHK"), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_U),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("UnlockBriefing: RegisterEventHotKey failed: \(status)")
            return
        }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let install = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    monitor.onPressed?()
                }
                return noErr
            },
            1,
            &spec,
            userData,
            &handler
        )
        if install != noErr {
            NSLog("UnlockBriefing: InstallEventHandler failed: \(install)")
        }
    }

    func unregister() {
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    deinit {
        unregister()
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for byte in string.utf8.prefix(4) {
        result = (result << 8) + OSType(byte)
    }
    return result
}
