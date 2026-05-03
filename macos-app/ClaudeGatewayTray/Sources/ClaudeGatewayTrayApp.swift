import SwiftUI

@main
struct ClaudeGatewayTrayApp: App {
    @StateObject private var model = MenuBarModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Label(L10n.tr("app.name"), systemImage: model.statusSymbolName)
        }
        .menuBarExtraStyle(.window)

        Window(L10n.tr("settings.window_title"), id: "settings") {
            SettingsView(model: model)
        }
        .defaultSize(width: 620, height: 520)
    }
}
