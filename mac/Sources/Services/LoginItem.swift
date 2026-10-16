import ServiceManagement

/// Open at Login through SMAppService. On by default (journey X20).
enum LoginItem {
    private static let configuredKey = "loginItemConfigured"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Auvel: login item change failed: \(error.localizedDescription)")
        }
    }

    /// Enables the login item once, on first launch. Later choices by the user are respected.
    static func enableOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: configuredKey) else { return }
        UserDefaults.standard.set(true, forKey: configuredKey)
        setEnabled(true)
    }
}
