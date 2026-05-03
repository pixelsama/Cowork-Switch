import Foundation

enum GatewayClientError: LocalizedError {
    case badStatus(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case let .badStatus(code, body):
            return "Gateway returned HTTP \(code): \(body)"
        case .invalidResponse:
            return "Gateway returned an invalid response."
        }
    }
}

struct GatewayClient {
    private static let defaultHost = "127.0.0.1"
    private static let defaultPort = 8787
    private static let defaultBaseURL = makeBaseURL(host: defaultHost, port: defaultPort)!

    var configPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CoworkSwitch/config.json")

    func fetchStatus(config: GatewayConfig? = nil) async throws -> GatewayStatus {
        try await request(baseURL: baseURL(for: config), path: "/_admin/status", method: "GET", body: Optional<Data>.none)
    }

    func fetchConfig(config: GatewayConfig? = nil) async throws -> GatewayConfig {
        try await request(baseURL: baseURL(for: config), path: "/_admin/config", method: "GET", body: Optional<Data>.none)
    }

    func saveConfig(_ config: GatewayConfig) async throws -> GatewayConfig {
        let data = try JSONEncoder().encode(config)
        return try await request(baseURL: baseURL(for: config), path: "/_admin/config", method: "PUT", body: data)
    }

    private func baseURL(for config: GatewayConfig?) -> URL {
        if let config, let url = Self.makeBaseURL(host: config.host, port: config.port) {
            return url
        }

        return configuredBaseURLFromDisk() ?? Self.defaultBaseURL
    }

    private func configuredBaseURLFromDisk() -> URL? {
        guard
            let data = try? Data(contentsOf: configPath),
            let config = try? JSONDecoder().decode(GatewayEndpointConfig.self, from: data),
            let host = config.host,
            let port = config.port
        else {
            return nil
        }

        return Self.makeBaseURL(host: host, port: port)
    }

    private static func makeBaseURL(host: String, port: Int) -> URL? {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let connectHost = ["", "0.0.0.0", "::"].contains(trimmedHost) ? defaultHost : trimmedHost
        var components = URLComponents()
        components.scheme = "http"
        components.host = connectHost
        components.port = port
        return components.url
    }

    private func request<Response: Decodable>(baseURL: URL, path: String, method: String, body: Data?) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 5

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<empty>"
            throw GatewayClientError.badStatus(httpResponse.statusCode, bodyText)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private struct GatewayEndpointConfig: Decodable {
    var host: String?
    var port: Int?
}
