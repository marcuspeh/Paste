import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var hotKeyManager: HotKeyManager
    @StateObject private var launchManager = LaunchManager()
    @State private var showSettings = false
    @State private var copiedItem: UUID? = nil
    @State private var selectedIndex = -1
    @State private var eventMonitor: Any? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            // Header Section
            VStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("Paste")
                    .font(.system(size: 20, weight: .bold))
            }
            .padding(.top, 20)
            
            // Main Content Card
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                
                if showSettings {
                    SettingsView(showSettings: $showSettings, launchManager: launchManager)
                        .transition(.opacity)
                    .resizable()
                    ClipboardListView(copiedItem: $copiedItem, selectedIndex: selectedIndex, selectItem: selectItem)
                        .transition(.opacity)
                }
                
                // Copied Overlay
                if copiedItem != nil {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Copied!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(width: 120, height: 120)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 16)
            
            // Footer Buttons
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        showSettings.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showSettings ? "clock.arrow.circlepath" : "gearshape")
                        Text(showSettings ? "History" : "Settings")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.4))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 320, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Reset state on appear
            selectedIndex = -1
            showSettings = false
            
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if showSettings { return event }
                
                switch event.keyCode {
                case 126: // Up
                    if selectedIndex == -1 {
                        if !clipboardManager.history.isEmpty {
                            selectedIndex = 0
                            return nil
                        }
                    } else if selectedIndex > 0 {
                        selectedIndex -= 1
                        return nil
                    }
                case 125: // Down
                    if selectedIndex == -1 {
                        if !clipboardManager.history.isEmpty {
                            selectedIndex = 0
                            return nil
                        }
                    } else if selectedIndex < clipboardManager.history.count - 1 {
                        selectedIndex += 1
                        return nil
                    }
                case 36: // Enter
                    if !clipboardManager.history.isEmpty {
                        let indexToUse = selectedIndex == -1 ? 0 : selectedIndex
                        if indexToUse < clipboardManager.history.count {
                            selectItem(clipboardManager.history[indexToUse])
                            return nil
                        }
                    }
                default:
                    break
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            selectedIndex = -1
            showSettings = false
        }
        .onChange(of: clipboardManager.history) { _ in
            if selectedIndex >= clipboardManager.history.count {
                selectedIndex = max(0, clipboardManager.history.count - 1)
            }
        }
    }
    
    private func selectItem(_ item: ClipboardItem) {
        // Show feedback
        withAnimation {
            copiedItem = item.id
        }
        
        clipboardManager.copyToPasteboard(item: item)
        
        // Delay closing to show feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Close popover
            clipboardManager.closePopover()
            // Paste
            PasteHelper.paste()
            // Reset feedback
            copiedItem = nil
        }
    }
}

struct ClipboardListView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Binding var copiedItem: UUID?
    var selectedIndex: Int
    let selectItem: (ClipboardItem) -> Void
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 1) {
                    if clipboardManager.history.isEmpty {
                        Text("No items yet")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(clipboardManager.history.enumerated()), id: \.element.id) { index, item in
                            ClipboardRow(item: item, isSelected: index == selectedIndex, selectItem: {
                                selectItem(item)
                            })
                            .id(index) // For ScrollViewReader
                            .opacity(copiedItem == item.id ? 0.5 : 1.0)
                        }
                    }
                }
                .padding(.vertical, 8)
                .onChange(of: selectedIndex) { newIndex in
                    if newIndex >= 0 {
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

struct ClipboardRow: View {
    @ObservedObject var item: ClipboardItem
    @EnvironmentObject var clipboardManager: ClipboardManager
    var isSelected: Bool
    let selectItem: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Content Icon
            Group {
                switch item.content {
                case .text:
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.blue)
                case .image(let img):
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(4)
                case .file(let url):
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                }
            }
            .frame(width: 24, height: 24)
            
            // Content Text
            VStack(alignment: .leading) {
                switch item.content {
                case .text(let text):
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .lineLimit(1)
                case .image:
                    Text("Image")
                case .file(let url):
                    Text(url.lastPathComponent)
                }
            }
            .font(.system(size: 13))
            .foregroundColor(.primary)
            
            Spacer()
            
            // Pin Button
            Button(action: {
                withAnimation {
                    clipboardManager.togglePin(for: item)
                }
            }) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .foregroundColor(item.isPinned ? .yellow : (isSelected ? .secondary : .secondary.opacity(0.5)))
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectItem()
        }
        .background(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.001))
        .cornerRadius(6)
        .padding(.horizontal, 4)
    }
}

struct SettingsView: View {
    @EnvironmentObject var hotKeyManager: HotKeyManager
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Binding var showSettings: Bool
    @ObservedObject var launchManager: LaunchManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            HStack{
                Label("Shortcut", systemImage: "keyboard")
                Spacer()
                ShortcutRecorder(keyCode: $hotKeyManager.shortcutKeyCode, modifiers: $hotKeyManager.shortcutModifiers) { k, m in
                    hotKeyManager.setShortcut(keyCode: k, modifiers: m)
                }
            }
            
            HStack {
                Label("History Limit", systemImage: "clock")
                Spacer()
                TextField("Limit", value: $clipboardManager.maxItems, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack{
                Label("Launch at Login", systemImage: "play.fill")
                Spacer()
                Toggle("", isOn: $launchManager.isLaunchAtLoginEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Button(action: {
                clipboardManager.clearAll()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Unpinned Items")
                }
                .foregroundColor(.red)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShortcutRecorder: View {
    @Binding var keyCode: Int
    @Binding var modifiers: UInt
    var onChange: (Int, UInt) -> Void
    @State private var isRecording = false
    
    var body: some View {
        Button(action: { isRecording = true }) {
            Text(isRecording ? "Press keys..." : shortcutString)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isRecording ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .background(WindowAccessor { window in
            if isRecording {
                window?.makeFirstResponder(nil)
            }
        })
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if isRecording {
                    if event.keyCode == 55 || event.keyCode == 56 || event.keyCode == 58 || event.keyCode == 59 || event.keyCode == 60 || event.keyCode == 61 || event.keyCode == 62 || event.keyCode == 54 {
                         return event
                    }
                    
                    if event.keyCode == 53 { 
                        isRecording = false
                        return nil
                    }
                    
                    onChange(Int(event.keyCode), event.modifierFlags.rawValue)
                    isRecording = false
                    return nil
                }
                return event
            }
        }
    }
    
    var shortcutString: String {
        var s = ""
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { s += "⌃" }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { s += "⌥" }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { s += "⇧" }
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { s += "⌘" }
        s += keyString(for: keyCode)
        return s
    }
    
    func keyString(for code: Int) -> String {
        switch code {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_Quote: return "\""
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Grave: return "`"
        case kVK_ANSI_KeypadDecimal: return "."
        case kVK_ANSI_KeypadMultiply: return "*"
        case kVK_ANSI_KeypadPlus: return "+"
        case kVK_ANSI_KeypadClear: return "Clear"
        case kVK_ANSI_KeypadDivide: return "/"
        case kVK_ANSI_KeypadEnter: return "Enter"
        case kVK_ANSI_KeypadMinus: return "-"
        case kVK_ANSI_KeypadEquals: return "="
        case kVK_ANSI_Keypad0: return "0"
        case kVK_ANSI_Keypad1: return "1"
        case kVK_ANSI_Keypad2: return "2"
        case kVK_ANSI_Keypad3: return "3"
        case kVK_ANSI_Keypad4: return "4"
        case kVK_ANSI_Keypad5: return "5"
        case kVK_ANSI_Keypad6: return "6"
        case kVK_ANSI_Keypad7: return "7"
        case kVK_ANSI_Keypad8: return "8"
        case kVK_ANSI_Keypad9: return "9"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "␣"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_Command: return "⌘"
        case kVK_Shift: return "⇧"
        case kVK_CapsLock: return "⇪"
        case kVK_Option: return "⌥"
        case kVK_Control: return "⌃"
        case kVK_RightShift: return "⇧"
        case kVK_RightOption: return "⌥"
        case kVK_RightControl: return "⌃"
        case kVK_Function: return "Fn"
        case kVK_F17: return "F17"
        case kVK_VolumeUp: return "Vol+"
        case kVK_VolumeDown: return "Vol-"
        case kVK_Mute: return "Mute"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F3: return "F3"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F11: return "F11"
        case kVK_F13: return "F13"
        case kVK_F16: return "F16"
        case kVK_F14: return "F14"
        case kVK_F10: return "F10"
        case kVK_F12: return "F12"
        case kVK_F15: return "F15"
        case kVK_Help: return "Help"
        case kVK_Home: return "Home"
        case kVK_PageUp: return "PgUp"
        case kVK_ForwardDelete: return "Del"
        case kVK_F4: return "F4"
        case kVK_End: return "End"
        case kVK_F2: return "F2"
        case kVK_PageDown: return "PgDn"
        case kVK_F1: return "F1"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_DownArrow: return "↓"
        case kVK_UpArrow: return "↑"
        default: return "?"
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
