import Foundation
import SwiftUI

@MainActor
final class MenuBarModel: ObservableObject {
    @Published var status: GatewayStatus?
    @Published var draftConfig = GatewayConfig.fallback
    @Published var lastErrorMessage = ""
    @Published var isRefreshing = false
    @Published var isSaving = false

    let launchAtLogin = LaunchAtLoginManager()

    private let client = GatewayClient()
    private var refreshTimer: Timer?
    private var hasLoadedConfig = false

    init() {
        startPolling()

        Task {
            await refreshAll()
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var isRunning: Bool {
        status?.ok == true
    }

    var endpointDescription: String {
        "http://\(draftConfig.host):\(draftConfig.port)"
    }

    var statusText: String {
        isRunning ? L10n.tr("status.running") : L10n.tr("status.unreachable")
    }

    var statusSymbolName: String {
        isRunning ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle"
    }

    var statusColor: Color {
        isRunning ? .green : .orange
    }

    var selectedProviderIndex: Int? {
        draftConfig.providers.firstIndex(where: { $0.id == draftConfig.activeProviderId })
    }

    var launchAtLoginSummary: String {
        launchAtLogin.isEnabled ? L10n.tr("launch_at_login.summary_enabled") : L10n.tr("launch_at_login.summary_disabled")
    }

    var fakeModelsText: String {
        guard let index = selectedProviderIndex else {
            return ""
        }

        return draftConfig.providers[index].fakeModels.joined(separator: "\n")
    }

    func refreshAll() async {
        launchAtLogin.refreshStatus()
        await loadConfig()
        await refreshStatus()
    }

    func refreshStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let status = try await client.fetchStatus(config: loadedConfig)
            self.status = status
            self.lastErrorMessage = ""
        } catch {
            self.status = nil
            self.lastErrorMessage = error.localizedDescription
        }
    }

    func loadConfig() async {
        do {
            let config = try await client.fetchConfig(config: loadedConfig)
            self.draftConfig = config
            self.hasLoadedConfig = true
            self.lastErrorMessage = ""
        } catch {
            self.lastErrorMessage = error.localizedDescription
        }
    }

    func saveConfig() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let saved = try await client.saveConfig(draftConfig)
            draftConfig = saved
            hasLoadedConfig = true
            lastErrorMessage = ""
            await refreshStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func addProvider() {
        addCustomProvider()
    }

    func addDeepSeekProvider() {
        appendProvider(
            GatewayProvider(
                id: nextProviderId(prefix: "deepseek"),
                name: "DeepSeek",
                providerKind: "deepseek",
                baseUrl: "https://api.deepseek.com/anthropic",
                apiKey: "",
                useFakeModels: true,
                fakeModels: ["deepseek-v4-pro", "deepseek-v4-flash"]
            )
        )
    }

    func addOpenRouterProvider() {
        appendProvider(
            GatewayProvider(
                id: nextProviderId(prefix: "openrouter"),
                name: "OpenRouter",
                providerKind: "openrouter",
                baseUrl: "https://openrouter.ai/api",
                apiKey: "",
                useFakeModels: false,
                fakeModels: []
            )
        )
    }

    func addCustomProvider() {
        let nextIndex = draftConfig.providers.count + 1
        appendProvider(
            GatewayProvider(
                id: nextProviderId(),
                name: L10n.format("provider.custom_name", nextIndex),
                providerKind: "generic",
                baseUrl: L10n.tr("provider.custom_base_url"),
                apiKey: "",
                useFakeModels: false,
                fakeModels: []
            )
        )
    }

    func removeSelectedProvider() {
        guard let index = selectedProviderIndex else {
            return
        }

        draftConfig.providers.remove(at: index)

        if draftConfig.providers.isEmpty {
            draftConfig = .fallback
        } else if !draftConfig.providers.contains(where: { $0.id == draftConfig.activeProviderId }) {
            draftConfig.activeProviderId = draftConfig.providers[0].id
        }
    }

    func updateSelectedProviderName(_ value: String) {
        updateSelectedProvider { $0.name = value }
    }

    func updateSelectedProviderBaseURL(_ value: String) {
        updateSelectedProvider { $0.baseUrl = value }
    }

    func updateSelectedProviderAPIKey(_ value: String) {
        updateSelectedProvider { $0.apiKey = value }
    }

    func updateSelectedProviderUseFakeModels(_ value: Bool) {
        updateSelectedProvider { $0.useFakeModels = value }
    }

    func updateFakeModelsText(_ value: String) {
        let models = value
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        updateSelectedProvider { $0.fakeModels = models }
    }

    private func updateSelectedProvider(_ mutate: (inout GatewayProvider) -> Void) {
        guard let index = selectedProviderIndex else {
            return
        }

        var provider = draftConfig.providers[index]
        mutate(&provider)
        draftConfig.providers[index] = provider
    }

    private func appendProvider(_ provider: GatewayProvider) {
        draftConfig.providers.append(provider)
        draftConfig.activeProviderId = provider.id
    }

    private func nextProviderId(prefix: String = "provider") -> String {
        var candidateIndex = draftConfig.providers.count + 1

        while draftConfig.providers.contains(where: { $0.id == "\(prefix)-\(candidateIndex)" }) {
            candidateIndex += 1
        }

        return "\(prefix)-\(candidateIndex)"
    }

    private var loadedConfig: GatewayConfig? {
        hasLoadedConfig ? draftConfig : nil
    }

    private func startPolling() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshStatus()
            }
        }
    }
}
