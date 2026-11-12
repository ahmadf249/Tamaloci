import Foundation
import SwiftData

/// SwiftData-backed pet persistence. Domain types in / out; no UI frameworks.
@MainActor
@Observable
final class PetRepository {
    private let modelContext: ModelContext

    private(set) var activePet: PetRecord?
    private(set) var memorials: [PetMemorialRecord] = []

    var hasCompletedOnboarding: Bool {
        activePet?.hasCompletedOnboarding == true
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        activePet = fetchActivePetRecord()
        memorials = fetchMemorialRecords()
    }

    // MARK: - Create / update

    @discardableResult
    func createPet(
        name: String,
        avatarConfiguration: AvatarConfiguration,
        createdAt: Date = Date(),
        birthDate: Date? = nil
    ) throws -> PetRecord {
        // Only one active pet at a time.
        try deactivateAllPets()

        let pet = SDPet(
            name: name,
            createdAt: createdAt,
            birthDate: birthDate ?? createdAt,
            lifeStage: .baby,
            avatarConfiguration: avatarConfiguration.clamped(),
            isActive: true
        )
        let needs = SDPetNeeds(from: .neutralDefaults)
        let state = SDPetState(from: .activeDefaults)
        pet.needs = needs
        pet.state = state
        needs.pet = pet
        state.pet = pet

        modelContext.insert(pet)
        try modelContext.save()
        refresh()
        return activePet!
    }

    func updateAvatar(_ configuration: AvatarConfiguration) throws {
        guard let pet = try fetchActiveSDPet() else { return }
        pet.avatarConfiguration = configuration.clamped()
        try modelContext.save()
        refresh()
    }

    // MARK: - Care history

    @discardableResult
    func appendCareEvent(type: CareEventType, note: String? = nil, at date: Date = Date()) throws -> CareEventRecord {
        guard let pet = try fetchActiveSDPet() else {
            throw PetRepositoryError.noActivePet
        }
        let event = SDCareEvent(type: type, timestamp: date, note: note)
        event.pet = pet
        pet.careEvents.append(event)
        modelContext.insert(event)
        try modelContext.save()
        return CareEventRecord(
            id: event.id,
            petID: pet.id,
            type: event.type,
            timestamp: event.timestamp,
            note: event.note
        )
    }

    func careEvents(for petID: UUID) throws -> [CareEventRecord] {
        let descriptor = FetchDescriptor<SDCareEvent>(
            predicate: #Predicate { $0.pet?.id == petID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map {
            CareEventRecord(
                id: $0.id,
                petID: petID,
                type: $0.type,
                timestamp: $0.timestamp,
                note: $0.note
            )
        }
    }

    // MARK: - Environment (schema only until M6)

    func upsertEnvironmentSnapshot(_ snapshot: EnvironmentSnapshotRecord) throws {
        guard let pet = try fetchActiveSDPet() else { return }
        let row = SDEnvironmentSnapshot(
            temperatureCelsius: snapshot.temperatureCelsius,
            conditionCode: snapshot.conditionCode,
            capturedAt: snapshot.capturedAt ?? Date()
        )
        row.pet = pet
        pet.environmentSnapshots.append(row)
        modelContext.insert(row)
        try modelContext.save()
    }

    // MARK: - Memorial

    @discardableResult
    func markActivePetDeceased(finalCondition: String = "deceased") throws -> PetMemorialRecord {
        guard let pet = try fetchActiveSDPet() else {
            throw PetRepositoryError.noActivePet
        }
        let ageDays = max(
            Calendar.current.dateComponents([.day], from: pet.birthDate, to: Date()).day ?? 0,
            0
        )
        let memorial = SDPetMemorial(
            petID: pet.id,
            name: pet.name,
            deathDate: Date(),
            ageDays: ageDays,
            finalCondition: finalCondition,
            avatarConfiguration: pet.avatarConfiguration
        )
        modelContext.insert(memorial)

        pet.isActive = false
        pet.state?.lifecycleStatusRaw = PetLifecycleState.deceased.rawValue
        pet.state?.conditionSummary = finalCondition
        pet.state?.lastUpdatedAt = Date()

        try modelContext.save()
        refresh()
        return PetMemorialRecord(
            id: memorial.id,
            petID: memorial.petID,
            name: memorial.name,
            deathDate: memorial.deathDate,
            ageDays: memorial.ageDays,
            finalCondition: memorial.finalCondition,
            avatarConfiguration: memorial.avatarConfiguration,
            createdAt: memorial.createdAt
        )
    }

    // MARK: - Debug / reset

    func clearAllForDebug() throws {
        try modelContext.delete(model: SDCareEvent.self)
        try modelContext.delete(model: SDEnvironmentSnapshot.self)
        try modelContext.delete(model: SDPetNeeds.self)
        try modelContext.delete(model: SDPetState.self)
        try modelContext.delete(model: SDPet.self)
        try modelContext.delete(model: SDPetMemorial.self)
        try modelContext.save()
        refresh()
    }

    // MARK: - Fetch helpers

    private func fetchActivePetRecord() -> PetRecord? {
        guard let pet = try? fetchActiveSDPet() else { return nil }
        return map(pet)
    }

    private func fetchActiveSDPet() throws -> SDPet? {
        var descriptor = FetchDescriptor<SDPet>(
            predicate: #Predicate { $0.isActive == true }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchMemorialRecords() -> [PetMemorialRecord] {
        let descriptor = FetchDescriptor<SDPetMemorial>(
            sortBy: [SortDescriptor(\.deathDate, order: .reverse)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        return rows.map {
            PetMemorialRecord(
                id: $0.id,
                petID: $0.petID,
                name: $0.name,
                deathDate: $0.deathDate,
                ageDays: $0.ageDays,
                finalCondition: $0.finalCondition,
                avatarConfiguration: $0.avatarConfiguration,
                createdAt: $0.createdAt
            )
        }
    }

    private func deactivateAllPets() throws {
        let descriptor = FetchDescriptor<SDPet>(predicate: #Predicate { $0.isActive == true })
        let actives = try modelContext.fetch(descriptor)
        for pet in actives {
            pet.isActive = false
        }
    }

    private func map(_ pet: SDPet) -> PetRecord {
        PetRecord(
            id: pet.id,
            name: pet.name,
            createdAt: pet.createdAt,
            birthDate: pet.birthDate,
            lifeStage: pet.lifeStage,
            avatarConfiguration: pet.avatarConfiguration,
            needs: pet.needs?.asDomain ?? .neutralDefaults,
            state: pet.state?.asDomain ?? .activeDefaults,
            isActive: pet.isActive
        )
    }
}

enum PetRepositoryError: LocalizedError {
    case noActivePet

    var errorDescription: String? {
        switch self {
        case .noActivePet: return "No active pet."
        }
    }
}
