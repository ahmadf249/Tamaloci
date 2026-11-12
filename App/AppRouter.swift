import SwiftUI

enum AppRoute: Equatable {
    case welcome
    case onboarding
    case petHome
}

@MainActor
@Observable
final class AppModel {
    var route: AppRoute
    let petStore: CreatedPetStore

    init(petStore: CreatedPetStore? = nil) {
        let store = petStore ?? CreatedPetStore()
        self.petStore = store
        self.route = store.hasCompletedOnboarding ? .petHome : .welcome
    }

    func refreshRoute() {
        route = petStore.hasCompletedOnboarding ? .petHome : .welcome
    }

    func startOnboarding() {
        route = .onboarding
    }

    func finishOnboarding(pet: CreatedPet) {
        petStore.save(pet)
        route = .petHome
    }

    #if DEBUG
    func resetOnboardingForDebug() {
        petStore.clear()
        route = .welcome
    }
    #endif
}

struct RootView: View {
    @State private var appModel = AppModel()

    var body: some View {
        Group {
            switch appModel.route {
            case .welcome:
                WelcomeView(appModel: appModel)
            case .onboarding:
                OnboardingFlowView(appModel: appModel)
            case .petHome:
                PetHomeView(appModel: appModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appModel.route)
    }
}
