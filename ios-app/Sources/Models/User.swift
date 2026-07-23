import Foundation

/// Mirrors `#/components/schemas/User`.
/// An account, identified by Sign in with Apple.
struct User: Codable, Identifiable, Equatable {
    let id: String            // uuid
    let createdAt: Date       // date-time
    let displayName: String?  // nullable
}

/// Mirrors `#/components/schemas/UserUpdate`.
/// Request body for `PATCH /me`. Omitted fields are left unchanged; an explicit
/// null clears the field.
///
/// Because "field omitted" and "field explicitly null" mean different things,
/// `displayName` is modeled as a nested optional and encoded manually so that
/// setting it to `.some(nil)` emits JSON `null`, while `.none` omits the key.
struct UserUpdate: Codable, Equatable {
    /// - `nil`         → key omitted (leave unchanged)
    /// - `.some(nil)`  → JSON null (clear the field)
    /// - `.some("x")`  → set to "x"
    var displayName: String??

    init(displayName: String?? = nil) {
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case displayName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch displayName {
        case .none:
            break // omit the key entirely
        case .some(let value):
            try container.encode(value, forKey: .displayName) // encodes null when value is nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.displayName) {
            let value = try container.decodeIfPresent(String.self, forKey: .displayName)
            displayName = .some(value)
        } else {
            displayName = .none
        }
    }
}
