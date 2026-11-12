import Foundation

/// Domain view of an active (or recently loaded) pet — free of SwiftData.
struct PetRecord: Equatable, Sendable, Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var birthDate: Date
    var lifeStage: PetLifeStage
    var avatarConfiguration: AvatarConfiguration
    var needs: PetNeeds
    var state: PetRuntimeState
    var isActive: Bool

    var hasCompletedOnboarding: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var ageDays: Int {
        max(Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0, 0)
    }
}

struct PetRuntimeState: Equatable, Sendable {
    var lifecycleStatus: PetLifecycleState
    var isSleeping: Bool
    var isIll: Bool
    var conditionSummary: String
    var lastUpdatedAt: Date

    static let activeDefaults = PetRuntimeState(
        lifecycleStatus: .active,
        isSleeping: false,
        isIll: false,
        conditionSummary: "healthy",
        lastUpdatedAt: Date()
    )
}

struct CareEventRecord: Equatable, Sendable, Identifiable {
    var id: UUID
    var petID: UUID
    var type: CareEventType
    var timestamp: Date
    var note: String?
}

struct PetMemorialRecord: Equatable, Sendable, Identifiable {
    var id: UUID
    var petID: UUID
    var name: String
    var deathDate: Date
    var ageDays: Int
    var finalCondition: String
    var avatarConfiguration: AvatarConfiguration
    var createdAt: Date
}

struct EnvironmentSnapshotRecord: Equatable, Sendable {
    var temperatureCelsius: Double?
    var conditionCode: String?
    var capturedAt: Date?
}
