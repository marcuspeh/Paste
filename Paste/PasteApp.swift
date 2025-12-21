import SwiftUI
import AppKit

@main
struct PasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Paste", systemImage: "doc.on.clipboard") {
            ContentView()
                .environmentObject(appDelegate.clipboardManager)
                .environmentObject(appDelegate.hotKeyManager)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var clipboardManager = ClipboardManager()
    var hotKeyManager = HotKeyManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKeyManager.setHotkeyTrigger(triggerFn: { [weak self] in
            self?.togglePopover(nil)
        })
        hotKeyManager.startHotkey()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        let statusItem = NSApp.windows.first?.value(forKey: "statusItem") as? NSStatusItem
        statusItem?.button?.performClick(nil)
    }

}
