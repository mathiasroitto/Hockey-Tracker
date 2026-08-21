import Foundation
import HockeyContract

enum APIError: Error, LocalizedError {
    case missingToken
    case unauthorized
    case server(status: Int, body: String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingToken: return "No auth token available yet."
        case .unauthorized: return "Not authorized (401)."
        case let .server(status, _): return "Server error (\(status))."
        case let .transport(error): return error.localizedDescription
        }
    }
}

/// Thin async/await client for the endpoints the Watch needs.
///
/// Only `POST /games/ingest` is implemented for the MVP. All requests carry the
/// bearer token from the `TokenProvider`.
struct APIClient {
    /// Configurable base URL. Defaults to the contract's local dev server.
    let baseURL: URL
    let tokenProvider: TokenProvider
    let session: URLSession

    init(
        baseURL: URL = URL(string: "http://localhost:8000")!,
        tokenProvider: TokenProvider,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session
    }

    /// Upload a finished game. Returns the decoded response body on success.
    /// Throws `APIError` — callers buffer + retry rather than surfacing to the
    /// capture UI.
    @discardableResult
    func ingest(_ game: GameIngest) async throws -> Data {
        guard let token = await tokenProvider.currentToken() else {
            throw APIError.missingToken
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("games/ingest"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try ContractJSON.encoder.encode(game)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return data
            }
            switch http.statusCode {
            case 200...299:
                return data
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.server(status: http.statusCode, body: String(decoding: data, as: UTF8.self))
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }
}
