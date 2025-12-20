import SwiftUI
import AppKit

@main
struct PasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var clipboardManager = ClipboardManager()
    var hotKeyManager = HotKeyManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the popover
        let contentView = ContentView()
            .environmentObject(clipboardManager)
            .environmentObject(hotKeyManager)
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.behavior = .transient // Closes when clicking outside
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste")
            button.action = #selector(togglePopover(_:))
        }
        
        // Setup HotKey        
        hotKeyManager.setHotkeyTrigger(triggerFn: { [weak self] in
            self?.togglePopover(nil)
        })
        hotKeyManager.startHotkey()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Activate app to ensure focus
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

}
