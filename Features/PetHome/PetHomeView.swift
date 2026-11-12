import SwiftUI

struct PetHomeView: View {
    @State private var expressionState = PetExpressionTestState()
    @State private var avatarStore = AvatarConfigurationStore()
    @State private var avatarConfiguration: AvatarConfiguration = .default
    @State private var characterViewID = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let brandTitle = "TAMA\"LO\"CI"

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Text(brandTitle)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 12)

                Text("M1 · avatar idle + expressions")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                PetCharacterView(
                    expression: expressionBinding,
                    avatarConfiguration: avatarConfiguration,
                    reduceMotion: reduceMotion
                )
                .id(characterViewID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)

                expressionHUD
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                avatarControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            avatarConfiguration = avatarStore.restore()
        }
    }

    private var expressionBinding: Binding<PetExpression> {
        Binding(
            get: { expressionState.expression },
            set: { expressionState.setExpression($0) }
        )
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.96, blue: 0.98),
                Color(red: 0.88, green: 0.92, blue: 0.90),
                Color(red: 0.96, green: 0.93, blue: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var expressionHUD: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Test state · expressions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                spacing: 8
            ) {
                ForEach(PetExpression.allCases) { item in
                    Button {
                        expressionState.setExpression(item)
                    } label: {
                        Text(item.displayName)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(expressionState.expression == item ? Color.accentColor : Color.secondary.opacity(0.35))
                    .accessibilityLabel("Set expression \(item.displayName)")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var avatarControls: some View {
        HStack(spacing: 8) {
            Button("Tweak look") {
                let usingDefault = abs(avatarConfiguration.eyeScale - 1) < 0.01
                let next: AvatarConfiguration
                if usingDefault {
                    next = AvatarConfiguration(
                        skinTint: AvatarColor(red: 0.93, green: 0.74, blue: 0.62),
                        eyeScale: 1.15,
                        browScale: 1.2
                    )
                } else {
                    next = .default
                }
                avatarConfiguration = next
                avatarStore.save(next)
            }
            .buttonStyle(.bordered)

            Button("Recreate view") {
                avatarConfiguration = avatarStore.restore()
                characterViewID = UUID()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Recreate avatar view from saved configuration")
        }
        .font(.caption.weight(.semibold))
    }
}

#Preview {
    PetHomeView()
}
