import SwiftUI
import Combine
import AppKit

enum ClipboardContent: Equatable, Codable {
    case text(String)
    case image(NSImage)
    case file(URL)
    
    enum CodingKeys: String, CodingKey {
        case type, content
    }
    
    enum ContentType: String, Codable {
        case text, image, file
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        
        switch type {
        case .text:
            let str = try container.decode(String.self, forKey: .content)
            self = .text(str)
        case .file:
            let url = try container.decode(URL.self, forKey: .content)
            self = .file(url)
        case .image:
            let data = try container.decode(Data.self, forKey: .content)
            guard let img = NSImage(data: data) else {
                throw DecodingError.dataCorruptedError(forKey: .content, in: container, debugDescription: "Invalid image data")
            }
            self = .image(img)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let str):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(str, forKey: .content)
        case .file(let url):
            try container.encode(ContentType.file, forKey: .type)
            try container.encode(url, forKey: .content)
        case .image(let img):
            try container.encode(ContentType.image, forKey: .type)
            if let tiff = img.tiffRepresentation {
                try container.encode(tiff, forKey: .content)
            } else {
                 // Fallback empty data if tiff fails
                 try container.encode(Data(), forKey: .content)
            }
        }
    }
    
    static func == (lhs: ClipboardContent, rhs: ClipboardContent) -> Bool {
        switch (lhs, rhs) {
        case (.text(let t1), .text(let t2)):
            return t1 == t2
        case (.file(let u1), .file(let u2)):
            return u1 == u2
        case (.image(let i1), .image(let i2)):
            return i1.tiffRepresentation == i2.tiffRepresentation
        default:
            return false
        }
    }
}

class ClipboardItem: Identifiable, Equatable, ObservableObject, Codable {
    let id: UUID
    let content: ClipboardContent
    let date: Date
    @Published var isPinned: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, content, date, isPinned
    }
    
    init(content: ClipboardContent, date: Date = Date(), isPinned: Bool = false) {
        self.id = UUID()
        self.content = content
        self.date = date
        self.isPinned = isPinned
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(ClipboardContent.self, forKey: .content)
        date = try container.decode(Date.self, forKey: .date)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(date, forKey: .date)
        try container.encode(isPinned, forKey: .isPinned)
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.content == rhs.content && lhs.isPinned == rhs.isPinned
    }
}

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    @Published var maxItems: Int {
        didSet {
            UserDefaults.standard.set(maxItems, forKey: "maxItems")
            enforceLimit()
        }
    }
    
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private let pinnedItemsKey = "pinnedItems"
    
    init() {
        self.lastChangeCount = pasteboard.changeCount
        self.maxItems = UserDefaults.standard.object(forKey: "maxItems") as? Int ?? 10
        loadPinnedItems()
        startMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    private func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // Check for Files (URLs)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstUrl = urls.first {
             addItem(.file(firstUrl))
             return
        }
        
        // Check for Images
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let firstImage = images.first {
            addItem(.image(firstImage))
            return
        }
        
        // Check for Strings
        if let newString = pasteboard.string(forType: .string) {
            addItem(.text(newString))
            return
        }
    }
    
    private func addItem(_ content: ClipboardContent) {
        // Avoid duplicates at the top or anywhere if existing
        if let existingIndex = history.firstIndex(where: { $0.content == content }) {
            // Move to top if it exists
            let item = history.remove(at: existingIndex)
            // Re-insert at top with current date, preserving pin status
            let newItem = ClipboardItem(content: item.content, date: Date(), isPinned: item.isPinned)
            
            // Insert logic based on pinning:
            // If it was pinned, it stays pinned. If not, it's new.
            // But we always want pinned items at top?
            // "For pinned items, it should always be at the top"
            insertItemSorted(newItem)
            return
        }
        
        let newItem = ClipboardItem(content: content)
        insertItemSorted(newItem)
        enforceLimit()
    }
    
    private func insertItemSorted(_ item: ClipboardItem) {
        // Strategy: Pinned items at top, sorted by date (newest first).
        // Unpinned items below, sorted by date.
        // Actually, usually you just put the newest item at the top of its section.
        
        // However, if we add a NEW item (unpinned), it goes below the last pinned item.
        // If we add a PINNED item (or toggle), it goes to the top of the list.
        
        // Let's just append and sort.
        history.insert(item, at: 0) // Naive insert
        sortHistory()
    }
    
    private func sortHistory() {
        history.sort { (item1, item2) -> Bool in
            if item1.isPinned != item2.isPinned {
                return item1.isPinned // Pinned first
            }
            return item1.date > item2.date // Newest first
        }
    }
    
    private func enforceLimit() {
        // Limit to maxItems
        // Strategy: Keep all pinned items. If count > maxItems, remove oldest unpinned items.
        
        while history.count > maxItems {
            // Find the last item that is NOT pinned
            if let lastUnpinnedIndex = history.lastIndex(where: { !$0.isPinned }) {
                history.remove(at: lastUnpinnedIndex)
            } else {
                // If all are pinned, we KEEP them (user pinned them explicitly).
                // Or should we remove oldest pinned? "max of 10 copied item".
                // Usually pinned items are exceptions to the limit.
                // But let's respect the limit if the user really wants 10.
                // "keep pinned items" implies persistence.
                // Let's assume pinned items count towards the limit but are prioritized.
                // If we have 11 pinned items and limit is 10, we probably shouldn't delete a pinned item automatically.
                // Let's break to avoid infinite loop if all are pinned.
                break
            }
        }
    }
    
    func togglePin(for item: ClipboardItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index].isPinned.toggle()
            sortHistory()
            savePinnedItems()
        }
    }
    
    func copyToPasteboard(item: ClipboardItem) {
        pasteboard.clearContents()
        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let image):
            pasteboard.writeObjects([image])
        case .file(let url):
            pasteboard.writeObjects([url as NSURL])
        }
    }
    
    func clearAll() {
        history.removeAll(where: { !$0.isPinned })
    }
    
    func closePopover() {
        let statusItem = NSApp.windows.first?.value(forKey: "statusItem") as? NSStatusItem
        statusItem?.button?.performClick(nil)
    }

    // MARK: - Persistence
    
    private func savePinnedItems() {
        let pinnedItems = history.filter { $0.isPinned }
        if let data = try? JSONEncoder().encode(pinnedItems) {
            UserDefaults.standard.set(data, forKey: pinnedItemsKey)
        }
    }
    
    private func loadPinnedItems() {
        guard let data = UserDefaults.standard.data(forKey: pinnedItemsKey) else { return }
        if let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            self.history = items
            sortHistory()
        }
    }
}
