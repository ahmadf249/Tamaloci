import SwiftUI

struct PetHomeView: View {
    @Bindable var appModel: AppModel
    @State private var expressionState = PetExpressionTestState()
    @State private var characterViewID = UUID()
    @State private var showDebugHUD = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let brandTitle = "TAMA\"LO\"CI"

    private var pet: PetRecord? { appModel.repository.activePet }

    private var avatarConfiguration: AvatarConfiguration {
        pet?.avatarConfiguration ?? .default
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                HStack {
                    Button("Memorial") {
                        appModel.showMemorial()
                    }
                    .font(.caption.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Text(brandTitle)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .onLongPressGesture(minimumDuration: 1.2) {
                        #if DEBUG
                        showDebugHUD.toggle()
                        #endif
                    }

                Text(pet.map(\.name) ?? "Your pet")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 4)

                Text("Your stylized companion — saved on device.")
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

                if showDebugHUD {
                    debugPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                } else {
                    Spacer().frame(height: 20)
                }
            }
        }
        .onAppear {
            appModel.repository.refresh()
            characterViewID = UUID()
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

    #if DEBUG
    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEBUG · expressions / persistence")
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
                }
            }

            HStack {
                Button("Append care") {
                    appModel.appendDebugCareEvent()
                }
                Button("Mark deceased") {
                    appModel.markDeceasedForDebug()
                }
                Button("Reset all") {
                    appModel.resetOnboardingForDebug()
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    #else
    private var debugPanel: some View { EmptyView() }
    #endif
}
