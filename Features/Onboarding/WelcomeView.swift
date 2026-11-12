import SwiftUI

struct WelcomeView: View {
    @Bindable var appModel: AppModel

    private let brandTitle = "TAMA\"LO\"CI"

    var body: some View {
        ZStack {
            brandBackground
            VStack(spacing: 28) {
                Spacer()
                Text(brandTitle)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text("A little pet that looks like you.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Create a stylized floating-head companion from a short face scan — or pick looks manually. Camera is optional.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                Button {
                    appModel.startOnboarding()
                } label: {
                    Text("Create my pet")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 28)

                if !appModel.repository.memorials.isEmpty {
                    Button("View memorial") {
                        appModel.showMemorial()
                    }
                    .padding(.bottom, 8)
                }

                Spacer().frame(height: 24)
            }
        }
        .onAppear {
            appModel.repository.refresh()
        }
    }

    private var brandBackground: some View {
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
}
