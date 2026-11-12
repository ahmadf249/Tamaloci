import SwiftData
import SwiftUI

enum AppRoute: Equatable {
    case welcome
    case onboarding
    case petHome
    case memorial
}

@MainActor
@Observable
final class AppModel {
    var route: AppRoute
    let repository: PetRepository

    init(repository: PetRepository) {
        self.repository = repository
        self.route = repository.hasCompletedOnboarding ? .petHome : .welcome
    }

    func refreshRoute() {
        repository.refresh()
        route = repository.hasCompletedOnboarding ? .petHome : .welcome
    }

    func startOnboarding() {
        route = .onboarding
    }

    func showMemorial() {
        repository.refresh()
        route = .memorial
    }

    func showPetHome() {
        repository.refresh()
        route = repository.hasCompletedOnboarding ? .petHome : .welcome
    }

    func finishOnboarding(name: String, avatarConfiguration: AvatarConfiguration, createdAt: Date = Date()) {
        do {
            _ = try repository.createPet(
                name: name,
                avatarConfiguration: avatarConfiguration,
                createdAt: createdAt,
                birthDate: createdAt
            )
            route = .petHome
        } catch {
            #if DEBUG
            print("finishOnboarding failed: \(error)")
            #endif
        }
    }

    #if DEBUG
    func resetOnboardingForDebug() {
        try? repository.clearAllForDebug()
        CreatedPetStore().clear()
        UserDefaults.standard.removeObject(forKey: "tamaloci.didMigrateCreatedPetToSwiftData")
        route = .welcome
    }

    func markDeceasedForDebug() {
        do {
            _ = try repository.markActivePetDeceased()
            route = .memorial
        } catch {
            print("markDeceased failed: \(error)")
        }
    }

    func appendDebugCareEvent() {
        try? repository.appendCareEvent(type: .feed, note: "DEBUG feed")
    }
    #endif
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appModel: AppModel?

    var body: some View {
        Group {
            if let appModel {
                routedContent(appModel)
            } else {
                ProgressView("Loading…")
                    .task {
                        let repository = PetRepository(modelContext: modelContext)
                        UserDefaultsPetMigrator.migrateIfNeeded(repository: repository)
                        appModel = AppModel(repository: repository)
                    }
            }
        }
    }

    @ViewBuilder
    private func routedContent(_ appModel: AppModel) -> some View {
        Group {
            switch appModel.route {
            case .welcome:
                WelcomeView(appModel: appModel)
            case .onboarding:
                OnboardingFlowView(appModel: appModel)
            case .petHome:
                PetHomeView(appModel: appModel)
            case .memorial:
                MemorialListView(appModel: appModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appModel.route)
    }
}
