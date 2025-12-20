import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var hotKeyManager: HotKeyManager
    @State private var showSettings = false
    @State private var copiedItem: UUID? = nil
    
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
                    SettingsView(showSettings: $showSettings)
                        .transition(.opacity)
                } else {
                    ClipboardListView(copiedItem: $copiedItem, selectItem: selectItem)
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
                    Text(showSettings ? "History" : "Settings")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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
    let selectItem: (ClipboardItem) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 1) {
                if clipboardManager.history.isEmpty {
                    Text("No items yet")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                } else {
                    ForEach(clipboardManager.history) { item in
                        ClipboardRow(item: item, selectItem: {
                            selectItem(item)
                        })
                        .opacity(copiedItem == item.id ? 0.5 : 1.0)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct ClipboardRow: View {
    @ObservedObject var item: ClipboardItem
    @EnvironmentObject var clipboardManager: ClipboardManager
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
                    .foregroundColor(item.isPinned ? .yellow : .secondary.opacity(0.5))
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
        .background(Color.white.opacity(0.001)) // For tap gesture
    }
}

struct SettingsView: View {
    @EnvironmentObject var hotKeyManager: HotKeyManager
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Binding var showSettings: Bool
    
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
                    Text("\(clipboardManager.maxItems)")
                        .font(.headline)
                }
                
                Stepper("", value: $clipboardManager.maxItems, in: 5...50, step: 1)
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
    }
}
