import Foundation
import SwiftData

@Model
final class SDPet {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var birthDate: Date
    var lifeStageRaw: String
    var avatarConfigData: Data
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \SDPetNeeds.pet)
    var needs: SDPetNeeds?

    @Relationship(deleteRule: .cascade, inverse: \SDPetState.pet)
    var state: SDPetState?

    @Relationship(deleteRule: .cascade, inverse: \SDCareEvent.pet)
    var careEvents: [SDCareEvent] = []

    @Relationship(deleteRule: .nullify, inverse: \SDEnvironmentSnapshot.pet)
    var environmentSnapshots: [SDEnvironmentSnapshot] = []

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        birthDate: Date = Date(),
        lifeStage: PetLifeStage = .baby,
        avatarConfiguration: AvatarConfiguration,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.birthDate = birthDate
        self.lifeStageRaw = lifeStage.rawValue
        self.avatarConfigData = (try? JSONEncoder().encode(avatarConfiguration)) ?? Data()
        self.isActive = isActive
    }

    var lifeStage: PetLifeStage {
        get { PetLifeStage(rawValue: lifeStageRaw) ?? .baby }
        set { lifeStageRaw = newValue.rawValue }
    }

    var avatarConfiguration: AvatarConfiguration {
        get {
            (try? JSONDecoder().decode(AvatarConfiguration.self, from: avatarConfigData)) ?? .default
        }
        set {
            avatarConfigData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}

@Model
final class SDPetNeeds {
    var hunger: Double
    var hydration: Double
    var happiness: Double
    var health: Double
    var cleanliness: Double
    var energy: Double
    var pet: SDPet?

    init(from needs: PetNeeds = .neutralDefaults) {
        hunger = needs.hunger
        hydration = needs.hydration
        happiness = needs.happiness
        health = needs.health
        cleanliness = needs.cleanliness
        energy = needs.energy
    }

    var asDomain: PetNeeds {
        PetNeeds(
            hunger: hunger,
            hydration: hydration,
            happiness: happiness,
            health: health,
            cleanliness: cleanliness,
            energy: energy
        )
    }

    func apply(_ needs: PetNeeds) {
        hunger = needs.hunger
        hydration = needs.hydration
        happiness = needs.happiness
        health = needs.health
        cleanliness = needs.cleanliness
        energy = needs.energy
    }
}

@Model
final class SDPetState {
    var lifecycleStatusRaw: String
    var isSleeping: Bool
    var isIll: Bool
    var conditionSummary: String
    var lastUpdatedAt: Date
    var pet: SDPet?

    init(from state: PetRuntimeState = .activeDefaults) {
        lifecycleStatusRaw = state.lifecycleStatus.rawValue
        isSleeping = state.isSleeping
        isIll = state.isIll
        conditionSummary = state.conditionSummary
        lastUpdatedAt = state.lastUpdatedAt
    }

    var asDomain: PetRuntimeState {
        PetRuntimeState(
            lifecycleStatus: PetLifecycleState(rawValue: lifecycleStatusRaw) ?? .active,
            isSleeping: isSleeping,
            isIll: isIll,
            conditionSummary: conditionSummary,
            lastUpdatedAt: lastUpdatedAt
        )
    }

    func apply(_ state: PetRuntimeState) {
        lifecycleStatusRaw = state.lifecycleStatus.rawValue
        isSleeping = state.isSleeping
        isIll = state.isIll
        conditionSummary = state.conditionSummary
        lastUpdatedAt = state.lastUpdatedAt
    }
}

@Model
final class SDCareEvent {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var timestamp: Date
    var note: String?
    var pet: SDPet?

    init(id: UUID = UUID(), type: CareEventType, timestamp: Date = Date(), note: String? = nil) {
        self.id = id
        self.typeRaw = type.rawValue
        self.timestamp = timestamp
        self.note = note
    }

    var type: CareEventType {
        CareEventType(rawValue: typeRaw) ?? .feed
    }
}

@Model
final class SDPetMemorial {
    @Attribute(.unique) var id: UUID
    var petID: UUID
    var name: String
    var deathDate: Date
    var ageDays: Int
    var finalCondition: String
    var avatarConfigData: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        petID: UUID,
        name: String,
        deathDate: Date = Date(),
        ageDays: Int,
        finalCondition: String,
        avatarConfiguration: AvatarConfiguration,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.petID = petID
        self.name = name
        self.deathDate = deathDate
        self.ageDays = ageDays
        self.finalCondition = finalCondition
        self.avatarConfigData = (try? JSONEncoder().encode(avatarConfiguration)) ?? Data()
        self.createdAt = createdAt
    }

    var avatarConfiguration: AvatarConfiguration {
        (try? JSONDecoder().decode(AvatarConfiguration.self, from: avatarConfigData)) ?? .default
    }
}

@Model
final class SDEnvironmentSnapshot {
    @Attribute(.unique) var id: UUID
    var temperatureCelsius: Double?
    var conditionCode: String?
    var capturedAt: Date?
    var pet: SDPet?

    init(
        id: UUID = UUID(),
        temperatureCelsius: Double? = nil,
        conditionCode: String? = nil,
        capturedAt: Date? = nil
    ) {
        self.id = id
        self.temperatureCelsius = temperatureCelsius
        self.conditionCode = conditionCode
        self.capturedAt = capturedAt
    }
}
