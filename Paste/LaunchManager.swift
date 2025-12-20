import Foundation
import ServiceManagement

class LaunchManager: ObservableObject {
    @Published var isLaunchAtLoginEnabled: Bool {
        didSet {
            updateLoginItem()
        }
    }
    
    init() {
        self.isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
    
    private func updateLoginItem() {
        do {
            if isLaunchAtLoginEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to update launch at login status: \(error)")
        }
    }
}
