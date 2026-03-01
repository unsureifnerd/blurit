import Foundation
import ServiceManagement

class LoginItemManager {
    static let shared = LoginItemManager()
    private init() {}

    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[LoginItemManager] Failed to \(enabled ? "register" : "unregister"): \(error)")
            }
        }
    }

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
