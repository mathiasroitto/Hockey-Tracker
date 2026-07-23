import SwiftUI

/// Generic loading model for a single async fetch. Drives the standard
/// loading / loaded / empty / error states used throughout the app.
@MainActor
final class Loadable<Value>: ObservableObject {
    enum Phase {
        case idle
        case loading
        case loaded(Value)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle

    /// The most recent operation, retained so `Retry` can re-run it.
    private var operation: (() async throws -> Value)?

    init(_ operation: (() async throws -> Value)? = nil) {
        self.operation = operation
    }

    /// Re-runs the last operation (used by Retry).
    func load() async {
        guard let operation else { return }
        await run(operation)
    }

    /// Runs a fresh operation and remembers it for future retries.
    func load(_ operation: @escaping () async throws -> Value) async {
        self.operation = operation
        await run(operation)
    }

    private func run(_ operation: () async throws -> Value) async {
        phase = .loading
        do {
            phase = .loaded(try await operation())
        } catch let error as APIError {
            phase = .failed(error.errorDescription ?? "Something went wrong.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// Renders a `Loadable` with consistent loading, error and empty states.
struct AsyncContentView<Value, Content: View>: View {
    @ObservedObject var loadable: Loadable<Value>
    /// Returns true when the loaded value should be treated as "empty".
    var isEmpty: (Value) -> Bool = { _ in false }
    var emptyMessage: String = "Nothing here yet."
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch loadable.phase {
        case .idle, .loading:
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await loadable.load() } }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded(let value):
            if isEmpty(value) {
                ContentUnavailableView {
                    Label("Nothing here yet", systemImage: "tray")
                } description: {
                    Text(emptyMessage)
                }
            } else {
                content(value)
            }
        }
    }
}
