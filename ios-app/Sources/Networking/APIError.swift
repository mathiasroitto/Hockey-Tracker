import Foundation

/// Errors surfaced by `APIClient`.
enum APIError: Error, LocalizedError, Equatable {
    /// 401 — token missing, invalid, or expired. Callers should prompt re-auth.
    case unauthorized(detail: String?)
    /// 404 — resource not found or not owned by the user.
    case notFound
    /// Any other non-2xx HTTP status.
    case http(status: Int, detail: String?)
    /// The request could not be built (e.g. bad URL).
    case invalidRequest(String)
    /// Response body could not be decoded into the expected model.
    case decoding(String)
    /// Transport-level failure (offline, timeout, TLS, …).
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized(let detail):
            return detail ?? "Your session has expired. Please sign in again."
        case .notFound:
            return "Not found."
        case .http(let status, let detail):
            return detail ?? "Server error (HTTP \(status))."
        case .invalidRequest(let msg):
            return "Invalid request: \(msg)"
        case .decoding(let msg):
            return "Could not read the server response: \(msg)"
        case .transport(let msg):
            return "Network error: \(msg)"
        }
    }
}
