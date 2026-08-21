import Foundation

/// Mirrors `#/components/schemas/User`.
/// An account, identified by Sign in with Apple.
public struct User: Codable, Identifiable, Equatable {
    public let id: String
    public let createdAt: Date
    public let displayName: String?

    public init(id: String, createdAt: Date, displayName: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.displayName = displayName
    }
}

/// Mirrors `#/components/schemas/UserUpdate`.
/// Request body for `PATCH /me`. Omitted fields are left unchanged; an explicit
/// null clears the field.
///
/// Because "field omitted" and "field explicitly null" mean different things,
/// `displayName` is a nested optional encoded manually:
///   - `nil`        → key omitted (leave unchanged)
///   - `.some(nil)` → JSON null (clear the field)
///   - `.some("x")` → set to "x"
public struct UserUpdate: Codable, Equatable {
    public var displayName: String??

    public init(displayName: String?? = nil) {
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case displayName
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch displayName {
        case .none:
            break // omit the key entirely
        case .some(let value):
            try container.encode(value, forKey: .displayName) // encodes null when value is nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.displayName) {
            let value = try container.decodeIfPresent(String.self, forKey: .displayName)
            displayName = .some(value)
        } else {
            displayName = .none
        }
    }
}
