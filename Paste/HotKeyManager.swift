import Cocoa
import Carbon

struct AppShortcut: Hashable, Identifiable, Codable {
    let id: UUID
    let name: String
    let keyCode: Int
    let modifiers: Int
    
    init(id: UUID = UUID(), name: String, keyCode: Int, modifiers: Int) {
        self.id = id
        self.name = name
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    
    static let defaults: [AppShortcut] = [
        AppShortcut(name: "Cmd + Shift + V", keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey),
        AppShortcut(name: "Cmd + Option + V", keyCode: kVK_ANSI_V, modifiers: cmdKey | optionKey),
        AppShortcut(name: "Ctrl + Shift + V", keyCode: kVK_ANSI_V, modifiers: controlKey | shiftKey),
        AppShortcut(name: "Cmd + Shift + C", keyCode: kVK_ANSI_C, modifiers: cmdKey | shiftKey),
        AppShortcut(name: "Option + Space", keyCode: kVK_Space, modifiers: optionKey)
    ]
}

class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotKeyTriggered: (() -> Void)?
    
    // Default: Cmd + Shift + V
    @Published var currentShortcut: AppShortcut {
        didSet {
            updateHotKey(keyCode: currentShortcut.keyCode, modifiers: currentShortcut.modifiers)
            saveShortcut()
        }
    }
    
    init() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "currentShortcut"),
           let saved = try? JSONDecoder().decode(AppShortcut.self, from: data) {
            self.currentShortcut = saved
        } else {
            self.currentShortcut = AppShortcut.defaults[0]
        }
        
        registerHotKey(keyCode: UInt32(currentShortcut.keyCode), modifiers: UInt32(currentShortcut.modifiers))
    }
    
    private func saveShortcut() {
        if let data = try? JSONEncoder().encode(currentShortcut) {
            UserDefaults.standard.set(data, forKey: "currentShortcut")
        }
    }
    
    func updateHotKey(keyCode: Int, modifiers: Int) {
        unregisterHotKey()
        registerHotKey(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
    }
    
    private func unregisterHotKey() {
        if let eventHotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
        }
    }
    
    private func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x53574654) // 'SWFT'
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &eventHotKeyRef)
        
        if status != noErr {
            print("Failed to register hot key: \(status)")
            return
        }
        
        // Install event handler if not already
        if eventHandler == nil {
            var eventType = EventTypeSpec()
            eventType.eventClass = OSType(kEventClassKeyboard)
            eventType.eventKind = OSType(kEventHotKeyPressed)
            
            let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            
            InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                DispatchQueue.main.async {
                    manager.onHotKeyTriggered?()
                }
                
                return noErr
            }, 1, &eventType, pointer, &eventHandler)
        }
    }
}
