import SwiftUI

struct AvatarEditorView: View {
    @Binding var configuration: AvatarConfiguration
    var continueTitle: String = "Looks good"
    var onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expression: PetExpression = .neutral

    var body: some View {
        VStack(spacing: 12) {
            PetCharacterView(
                expression: $expression,
                avatarConfiguration: configuration,
                reduceMotion: reduceMotion
            )
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .padding(.horizontal, 8)
            .accessibilityLabel("Pet avatar preview")

            Form {
                Section("Likeness (from scan — tweak if needed)") {
                    slider("Face length", value: $configuration.faceLength, range: 0.9...1.15)
                    slider("Head width", value: $configuration.headWidth, range: 0.85...1.2)
                    slider("Jaw", value: $configuration.jawWidth, range: 0.85...1.25)
                    slider("Hair coverage", value: $configuration.hairCoverage, range: 0.15...1.0)
                }
                Section("Features") {
                    slider("Eye size", value: $configuration.eyeScale, range: 0.75...1.35)
                    slider("Eye spacing", value: $configuration.eyeSpacing, range: 0.8...1.25)
                    slider("Brows", value: $configuration.browScale, range: 0.7...1.4)
                    slider("Nose", value: $configuration.noseScale, range: 0.75...1.35)
                    slider("Mouth", value: $configuration.mouthWidth, range: 0.75...1.4)
                }
                Section {
                    Button("Reset to defaults") {
                        configuration = .default
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxHeight: 320)

            Button(action: onContinue) {
                Text(continueTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .accessibilityHint("Saves the avatar look")
        }
        .onChange(of: configuration) { _, newValue in
            configuration = newValue.clamped()
        }
    }

    private func slider(_ title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading) {
            Text(title)
            Slider(value: value, in: range)
        }
    }
}
