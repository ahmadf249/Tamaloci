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
        self.route = Self.routeForCurrentPets(repository)
    }

    func refreshRoute() {
        repository.refresh()
        route = Self.routeForCurrentPets(repository)
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
        // Explicit navigation: home if alive, otherwise welcome (memorial keeps its own CTA).
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

    /// Apply a tick and route to memorial if the pet died from neglect.
    @discardableResult
    func tickActivePet(now: Date = Date()) -> PetRepository.TickResult? {
        guard repository.activePet != nil else { return nil }
        do {
            let result = try repository.tick(now: now)
            applyTickResult(result)
            return result
        } catch {
            #if DEBUG
            print("tick failed: \(error)")
            #endif
            return nil
        }
    }

    func applyTickResult(_ result: PetRepository.TickResult) {
        if case .deceased = result {
            route = .memorial
        }
    }

    private static func routeForCurrentPets(_ repository: PetRepository) -> AppRoute {
        if repository.hasCompletedOnboarding {
            return .petHome
        }
        if !repository.memorials.isEmpty {
            return .memorial
        }
        return .welcome
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
        if let result = try? repository.performCare(.feed, note: "DEBUG feed") {
            applyTickResult(result)
        }
    }

    func advanceSimulationHoursForDebug(_ hours: Double) {
        guard let pet = repository.activePet else { return }
        var state = pet.state
        state.lastUpdatedAt = state.lastUpdatedAt.addingTimeInterval(-hours * 3600)
        try? repository.save(needs: pet.needs, state: state, lifeStage: pet.lifeStage)
        _ = tickActivePet()
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
