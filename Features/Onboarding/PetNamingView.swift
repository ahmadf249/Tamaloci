import SwiftUI

struct PetNamingView: View {
    @Binding var name: String
    var configuration: AvatarConfiguration
    var onCreate: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expression: PetExpression = .happy

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 16) {
            PetCharacterView(
                expression: $expression,
                avatarConfiguration: configuration,
                reduceMotion: reduceMotion
            )
            .frame(height: 220)
            .padding(.horizontal, 8)

            Text("What should we call your pet?")
                .font(.title3.weight(.semibold))

            TextField("Pet name", text: $name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 24)

            Text("Up to 24 characters. You can rename later in a future update.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onCreate) {
                Text("Meet \(trimmed.isEmpty ? "my pet" : trimmed)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmed.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
}
