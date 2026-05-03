import SwiftUI

@main
struct CoworkSwitchApp: App {
    @StateObject private var model = MenuBarModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.window)

        Window(L10n.tr("settings.window_title"), id: "settings") {
            SettingsView(model: model)
        }
        .defaultSize(width: 620, height: 520)
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        if let icon = resizedMenuBarIcon() {
            Image(nsImage: icon)
        } else {
            Image(systemName: model.statusSymbolName)
        }
    }

    private func resizedMenuBarIcon() -> NSImage? {
        guard let source = NSImage(named: "AppIcon") else {
            return nil
        }

        let targetSize = NSSize(width: 18, height: 18)

        guard let resized = source.copy() as? NSImage else {
            return nil
        }

        resized.size = targetSize
        resized.isTemplate = false
        return resized
    }
}
