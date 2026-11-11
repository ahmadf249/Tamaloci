import SwiftUI

struct PetHomeView: View {
    @State private var expression: PetExpression = .neutral
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

                Text("Phase I · floating head + expression POC")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                PetCharacterView(expression: $expression, reduceMotion: reduceMotion)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)

                expressionHUD
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
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
            Text("Expressions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                spacing: 8
            ) {
                ForEach(PetExpression.allCases) { item in
                    Button {
                        expression = item
                    } label: {
                        Text(item.displayName)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(expression == item ? Color.accentColor : Color.secondary.opacity(0.35))
                    .accessibilityLabel("Set expression \(item.displayName)")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    PetHomeView()
}
