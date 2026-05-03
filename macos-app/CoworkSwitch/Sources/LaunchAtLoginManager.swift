import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled = false
    @Published var statusMessage = ""
    @Published var errorMessage = ""

    private let defaults: UserDefaults
    private let initializedKey = "launchAtLoginPreferenceInitialized"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refreshStatus()

        Task {
            await enableByDefaultIfNeeded()
        }
    }

    func toggle(_ enabled: Bool) async {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }

            errorMessage = ""
            refreshStatus()
        } catch {
            refreshStatus()
            errorMessage = error.localizedDescription
        }
    }

    func refreshStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            statusMessage = L10n.tr("launch_at_login.status_enabled")
        case .requiresApproval:
            isEnabled = false
            statusMessage = L10n.tr("launch_at_login.status_requires_approval")
        case .notFound:
            isEnabled = false
            statusMessage = L10n.tr("launch_at_login.status_not_found")
        case .notRegistered:
            isEnabled = false
            statusMessage = L10n.tr("launch_at_login.status_disabled")
        @unknown default:
            isEnabled = false
            statusMessage = L10n.tr("launch_at_login.status_unknown")
        }
    }

    private func enableByDefaultIfNeeded() async {
        guard defaults.bool(forKey: initializedKey) == false else {
            return
        }

        defaults.set(true, forKey: initializedKey)

        if SMAppService.mainApp.status != .enabled {
            await toggle(true)
        } else {
            refreshStatus()
        }
    }
}
