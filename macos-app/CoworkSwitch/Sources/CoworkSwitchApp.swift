import SwiftUI

@main
struct CoworkSwitchApp: App {
    @StateObject private var model = MenuBarModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
            } else {
                Image(systemName: model.statusSymbolName)
            }
        }
        .menuBarExtraStyle(.window)

        Window(L10n.tr("settings.window_title"), id: "settings") {
            SettingsView(model: model)
        }
        .defaultSize(width: 620, height: 520)
    }
}
