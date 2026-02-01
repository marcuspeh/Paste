import Cocoa
import Carbon


final class HotKey {
    var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func start(keyCode: UInt32 = UInt32(kVK_ANSI_Y), modifiers: UInt32 = UInt32(cmdKey | shiftKey)) {
        stop()
        var hotKeyID = EventHotKeyID(signature: OSType("LMST".fourCharCodeValue), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger?()
            return noErr
        }, 1, &spec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandler)
    }

    func stop() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let handler = eventHandler { RemoveEventHandler(handler); eventHandler = nil }
    }
}


private extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for unicodeScalar in self.unicodeScalars {
            result = (result << 8) + UInt32(unicodeScalar.value)
        }
        return result
    }
}

class HotKeyManager: ObservableObject {
    let hotKey = HotKey()
    
    @Published var shortcutKeyCode: Int = UserDefaults.standard.integer(forKey: "shortcutKeyCode")
    @Published var shortcutModifiers: UInt = UInt(UserDefaults.standard.integer(forKey: "shortcutModifiers"))

    func setHotkeyTrigger(triggerFn: (() -> Void)?) {
        hotKey.onTrigger = triggerFn
    }
    
    func setShortcut(keyCode: Int, modifiers: UInt) {
        shortcutKeyCode = keyCode
        shortcutModifiers = modifiers
        UserDefaults.standard.set(keyCode, forKey: "shortcutKeyCode")
        UserDefaults.standard.set(modifiers, forKey: "shortcutModifiers")
        updateHotkey()
    }
    
    func startHotkey() {
        // Default to Cmd+Shift+V (kVK_ANSI_V = 0x17 = 23)
        // If nothing stored, use default
        if shortcutKeyCode == 0 && shortcutModifiers == 0 {
            shortcutKeyCode = kVK_ANSI_V
            shortcutModifiers = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.control.rawValue
        }
        
        updateHotkey()
    }
    
    func updateHotkey() {
        var carbonModifiers: UInt32 = 0
        if shortcutModifiers & NSEvent.ModifierFlags.command.rawValue != 0 { carbonModifiers |= UInt32(cmdKey) }
        if shortcutModifiers & NSEvent.ModifierFlags.option.rawValue != 0 { carbonModifiers |= UInt32(optionKey) }
        if shortcutModifiers & NSEvent.ModifierFlags.control.rawValue != 0 { carbonModifiers |= UInt32(controlKey) }
        if shortcutModifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { carbonModifiers |= UInt32(shiftKey) }
        
        hotKey.start(keyCode: UInt32(shortcutKeyCode), modifiers: carbonModifiers)
    }
}
