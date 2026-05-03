import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: MenuBarModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(model.statusColor)
                    .frame(width: 10, height: 10)

                Text(model.statusText)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("menu.endpoint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.endpointDescription)
                    .font(.system(.body, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("menu.launch_at_login"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.launchAtLoginSummary)
                    .font(.body.weight(.medium))
                    .foregroundStyle(model.launchAtLogin.isEnabled ? .green : .secondary)
            }

            if let status = model.status {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("menu.active_provider"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(status.activeProvider.name)
                        .font(.body.weight(.medium))
                    Text(status.activeProvider.baseUrl)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(status.activeProvider.useFakeModels ? L10n.tr("menu.fake_models_enabled") : L10n.tr("menu.direct_models"))
                        .font(.caption)
                        .foregroundStyle(status.activeProvider.useFakeModels ? .green : .secondary)
                }
            }

            if !model.lastErrorMessage.isEmpty {
                Text(model.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(model.isRefreshing ? L10n.tr("menu.refreshing") : L10n.tr("menu.refresh")) {
                    Task {
                        await model.refreshAll()
                    }
                }
                .disabled(model.isRefreshing)

                Button(L10n.tr("menu.settings")) {
                    showSettingsWindow()
                }
            }

            Divider()

            Button(L10n.tr("menu.quit")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func showSettingsWindow() {
        openWindow(id: "settings")
        bringSettingsWindowToFront()
    }

    private func bringSettingsWindowToFront(attempt: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: false)

            if let window = NSApp.windows.first(where: {
                $0.title == L10n.tr("settings.window_title")
            }) {
                window.makeKeyAndOrderFront(nil)
                return
            }

            if attempt < 3 {
                bringSettingsWindowToFront(attempt: attempt + 1)
            }
        }
    }
}
