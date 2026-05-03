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
    var baseURL = URL(string: "http://127.0.0.1:8787")!

    func fetchStatus() async throws -> GatewayStatus {
        try await request(path: "/_admin/status", method: "GET", body: Optional<Data>.none)
    }

    func fetchConfig() async throws -> GatewayConfig {
        try await request(path: "/_admin/config", method: "GET", body: Optional<Data>.none)
    }

    func saveConfig(_ config: GatewayConfig) async throws -> GatewayConfig {
        let data = try JSONEncoder().encode(config)
        return try await request(path: "/_admin/config", method: "PUT", body: data)
    }

    private func request<Response: Decodable>(path: String, method: String, body: Data?) async throws -> Response {
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
