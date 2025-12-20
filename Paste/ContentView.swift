import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var hotKeyManager: HotKeyManager
    @StateObject private var launchManager = LaunchManager()
    @State private var showSettings = false
    @State private var copiedItem: UUID? = nil
    @State private var selectedIndex = 0
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
                } else {
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
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if showSettings { return event }
                
                switch event.keyCode {
                case 126: // Up
                    if selectedIndex > 0 {
                        selectedIndex -= 1
                        return nil
                    }
                case 125: // Down
                    if selectedIndex < clipboardManager.history.count - 1 {
                        selectedIndex += 1
                        return nil
                    }
                case 36: // Enter
                    if !clipboardManager.history.isEmpty && selectedIndex < clipboardManager.history.count {
                        selectItem(clipboardManager.history[selectedIndex])
                        return nil
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Close popover
            (NSApplication.shared.delegate as? AppDelegate)?.togglePopover(nil)
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
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
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
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            // Shortcut Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Shortcut")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $hotKeyManager.currentShortcut) {
                    ForEach(AppShortcut.defaults) { shortcut in
                        Text(shortcut.name).tag(shortcut)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // History Limit
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("History Limit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("Limit", value: $clipboardManager.maxItems, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Divider()
            
            // Launch at Login
            HStack {
                Text("Launch at Login")
                Spacer()
                Toggle("", isOn: $launchManager.isLaunchAtLoginEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            Divider()
            
            // Clear History Button
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
