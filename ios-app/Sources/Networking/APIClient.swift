import Foundation
import HockeyContract

/// Supplies the current Sign in with Apple identity token to the API client.
/// Kept as a protocol so the client is testable and decoupled from the auth UI.
protocol TokenProviding: AnyObject {
    var identityToken: String? { get }
}

/// Async/await client for the Hockey-Tracker server API described in
/// `contract/openapi.yaml`.
///
/// The app DISPLAYS server-computed data; it never recomputes stats. Every
/// request (except `/health`) carries `Authorization: Bearer <token>`.
final class APIClient {

    let baseURL: URL
    private let session: URLSession
    private weak var tokenProvider: TokenProviding?
    private let decoder = ContractJSON.decoder
    private let encoder = ContractJSON.encoder

    /// - Parameters:
    ///   - baseURL: server base URL. Defaults to the local dev server.
    ///   - tokenProvider: source of the bearer token (usually the AuthSession).
    ///   - session: injectable for tests.
    init(
        baseURL: URL = URL(string: "http://localhost:8000")!,
        tokenProvider: TokenProviding? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session
    }

    func setTokenProvider(_ provider: TokenProviding) {
        self.tokenProvider = provider
    }

    // MARK: - Endpoints

    /// `GET /me`
    func me() async throws -> User {
        try await send(method: "GET", path: "/me")
    }

    /// `PATCH /me`
    func updateMe(_ update: UserUpdate) async throws -> User {
        let body: Data
        do {
            body = try encoder.encode(update)
        } catch {
            throw APIError.invalidRequest("Could not encode UserUpdate: \(error)")
        }
        return try await send(method: "PATCH", path: "/me", bodyData: body)
    }

    /// `GET /games` with optional filters.
    func games(opponent: String? = nil, from: Date? = nil, to: Date? = nil) async throws -> [Game] {
        var items: [URLQueryItem] = []
        if let opponent, !opponent.isEmpty {
            items.append(URLQueryItem(name: "opponent", value: opponent))
        }
        if let from {
            items.append(URLQueryItem(name: "from", value: ContractDate.calendarString(from: from)))
        }
        if let to {
            items.append(URLQueryItem(name: "to", value: ContractDate.calendarString(from: to)))
        }
        return try await send(method: "GET", path: "/games", query: items)
    }

    /// `GET /games/{gameId}`
    func game(id: String) async throws -> Game {
        try await send(method: "GET", path: "/games/\(id)")
    }

    /// `GET /games/{gameId}/stats`
    func gameStats(id: String) async throws -> GameStats {
        try await send(method: "GET", path: "/games/\(id)/stats")
    }

    /// `GET /stats/career`
    func careerStats() async throws -> CareerStats {
        try await send(method: "GET", path: "/stats/career")
    }

    // MARK: - Core request machinery

    private func send<Response: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        bodyData: Data? = nil
    ) async throws -> Response {
        let data = try await perform(method: method, path: path, query: query, bodyData: bodyData)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func perform(
        method: String,
        path: String,
        query: [URLQueryItem],
        bodyData: Data?
    ) async throws -> Data {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidRequest("Could not build URL for \(path)")
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else {
            throw APIError.invalidRequest("Invalid query for \(path)")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = tokenProvider?.identityToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let bodyData {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = bodyData
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Non-HTTP response")
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized(detail: Self.detail(from: data))
        case 404:
            throw APIError.notFound
        default:
            throw APIError.http(status: http.statusCode, detail: Self.detail(from: data))
        }
    }

    /// Extracts FastAPI's `{ "detail": "..." }` error message when present.
    private static func detail(from data: Data) -> String? {
        struct ErrorBody: Decodable { let detail: String? }
        return (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail
    }
}
