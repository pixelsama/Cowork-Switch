import Foundation

struct GatewayProvider: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var providerKind: String
    var baseUrl: String
    var apiKey: String
    var useFakeModels: Bool
    var fakeModels: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case providerKind
        case baseUrl
        case apiKey
        case useFakeModels
        case fakeModels
    }

    init(
        id: String,
        name: String,
        providerKind: String,
        baseUrl: String,
        apiKey: String,
        useFakeModels: Bool,
        fakeModels: [String]
    ) {
        self.id = id
        self.name = name
        self.providerKind = providerKind
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.useFakeModels = useFakeModels
        self.fakeModels = fakeModels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        providerKind = try container.decodeIfPresent(String.self, forKey: .providerKind) ?? "generic"
        baseUrl = try container.decode(String.self, forKey: .baseUrl)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        useFakeModels = try container.decodeIfPresent(Bool.self, forKey: .useFakeModels) ?? false
        fakeModels = try container.decodeIfPresent([String].self, forKey: .fakeModels) ?? []
    }
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
                providerKind: "deepseek",
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
