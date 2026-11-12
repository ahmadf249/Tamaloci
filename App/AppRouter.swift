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
    var userFacingError: String?

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
            userFacingError = nil
            route = .petHome
        } catch {
            userFacingError = "Couldn’t save your pet. Please try again."
            #if DEBUG
            print("finishOnboarding failed: \(error)")
            #endif
        }
    }

    @discardableResult
    func tickActivePet(
        now: Date = Date(),
        context: SimulationContext = .empty
    ) -> PetRepository.TickResult? {
        guard repository.activePet != nil else { return nil }
        do {
            let result = try repository.tick(now: now, context: context)
            applyTickResult(result)
            return result
        } catch {
            userFacingError = "Couldn’t update your pet right now."
            #if DEBUG
            print("tick failed: \(error)")
            #endif
            return nil
        }
    }

    @discardableResult
    func refreshDeviceIntegrationsAndTick(now: Date = Date()) async -> PetRepository.TickResult? {
        guard repository.activePet != nil else { return nil }

        if let fresh = await WeatherEnvironmentService.shared.fetchCurrentSnapshot() {
            try? repository.upsertEnvironmentSnapshot(fresh)
        }

        let context = SimulationContext(
            environment: repository.latestEnvironmentSnapshot(),
            batteryCharging: BatterySleepMonitor.shared.isCharging
        )
        let result = tickActivePet(now: now, context: context)
        await CareNotificationScheduler.shared.sync(pet: repository.activePet)
        return result
    }

    func applyTickResult(_ result: PetRepository.TickResult) {
        if case .deceased = result {
            route = .memorial
            Task {
                await CareNotificationScheduler.shared.sync(pet: nil)
            }
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
            Task { await CareNotificationScheduler.shared.sync(pet: nil) }
        } catch {
            print("markDeceased failed: \(error)")
        }
    }

    func appendDebugCareEvent() {
        if let result = try? repository.performCare(.feed, note: "DEBUG feed") {
            applyTickResult(result)
            Task { await CareNotificationScheduler.shared.sync(pet: repository.activePet) }
        }
    }

    func advanceSimulationHoursForDebug(_ hours: Double) {
        guard let pet = repository.activePet else { return }
        var state = pet.state
        state.lastUpdatedAt = state.lastUpdatedAt.addingTimeInterval(-hours * 3600)
        try? repository.save(needs: pet.needs, state: state, lifeStage: pet.lifeStage)
        let context = SimulationContext(
            environment: repository.latestEnvironmentSnapshot(),
            batteryCharging: BatterySleepMonitor.shared.isCharging
        )
        _ = tickActivePet(context: context)
        Task { await CareNotificationScheduler.shared.sync(pet: repository.activePet) }
    }
    #endif
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appModel: AppModel?
    @State private var showEphemeralStoreAlert = false

    var body: some View {
        Group {
            if let appModel {
                routedContent(appModel)
                    .alert("Couldn’t save pet", isPresented: Binding(
                        get: { appModel.userFacingError != nil },
                        set: { if !$0 { appModel.userFacingError = nil } }
                    )) {
                        Button("OK", role: .cancel) { appModel.userFacingError = nil }
                    } message: {
                        Text(appModel.userFacingError ?? "")
                    }
            } else {
                ProgressView("Loading…")
                    .task {
                        let repository = PetRepository(modelContext: modelContext)
                        UserDefaultsPetMigrator.migrateIfNeeded(repository: repository)
                        appModel = AppModel(repository: repository)
                        if AppLaunchDiagnostics.usedInMemoryStore {
                            showEphemeralStoreAlert = true
                        }
                    }
            }
        }
        .alert("Storage unavailable", isPresented: $showEphemeralStoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your pet may not persist after quit. Try relaunching the app. \(AppLaunchDiagnostics.storeErrorDescription ?? "")")
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: appModel.route)
    }
}
