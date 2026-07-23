import SwiftUI

/// Sheet for setting/clearing the display name via `PATCH /me`.
struct ProfileEditorView: View {
    let currentName: String?

    @EnvironmentObject private var session: AuthSession
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false

    init(currentName: String?) {
        self.currentName = currentName
        _name = State(initialValue: currentName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Display name") {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("This is shown on your profile. Leave it empty to clear it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            await session.updateDisplayName(name)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}
