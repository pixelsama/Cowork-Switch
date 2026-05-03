import Foundation

struct GatewayProvider: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var baseUrl: String
    var apiKey: String
    var useFakeModels: Bool
    var fakeModels: [String]
}

struct GatewayConfig: Codable, Equatable {
    var host: String
    var port: Int
    var activeProviderId: String
    var providers: [GatewayProvider]

    static let fallback = GatewayConfig(
        host: "127.0.0.1",
        port: 8787,
        activeProviderId: "deepseek",
        providers: [
            GatewayProvider(
                id: "deepseek",
                name: "DeepSeek",
                baseUrl: "https://api.deepseek.com/anthropic",
                apiKey: "",
                useFakeModels: true,
                fakeModels: ["deepseek-v4-pro", "deepseek-v4-flash"]
            )
        ]
    )
}

struct GatewayStatus: Codable, Equatable {
    var ok: Bool
    var service: String
    var configPath: String?
    var activeProvider: GatewayProvider
    var host: String
    var port: Int
}
