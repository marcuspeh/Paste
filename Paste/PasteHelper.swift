import Foundation
import ApplicationServices
import Cocoa

class PasteHelper {
    static func paste() {
        // Give time for the application to switch focus back to the target app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .hidSystemState)
            
            let vKey = 0x09 // kVK_ANSI_V
            
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(vKey), keyDown: true)
            keyDown?.flags = .maskCommand
            
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(vKey), keyDown: false)
            keyUp?.flags = .maskCommand
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
