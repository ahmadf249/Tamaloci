import SwiftData
import XCTest
@testable import Tamaloci

@MainActor
final class PetRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: PetRepository!

    override func setUpWithError() throws {
        container = try TamalociModelContainer.make(inMemory: true)
        repository = PetRepository(modelContext: ModelContext(container))
    }

    func testCreateAndFetchActivePet() throws {
        let pet = try repository.createPet(
            name: "Mochi",
            avatarConfiguration: .default
        )
        XCTAssertEqual(pet.name, "Mochi")
        XCTAssertTrue(repository.hasCompletedOnboarding)
        let health = try XCTUnwrap(repository.activePet?.needs.health)
        XCTAssertEqual(health, 100, accuracy: 0.001)
    }

    func testCareEventPersists() throws {
        _ = try repository.createPet(name: "Mochi", avatarConfiguration: .default)
        let event = try repository.appendCareEvent(type: .feed, note: "snack")
        XCTAssertEqual(event.type, .feed)
        let events = try repository.careEvents(for: repository.activePet!.id)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.note, "snack")
    }

    func testMarkDeceasedCreatesMemorialAndClearsActive() throws {
        _ = try repository.createPet(name: "Mochi", avatarConfiguration: .default)
        let memorial = try repository.markActivePetDeceased(finalCondition: "peaceful")
        XCTAssertEqual(memorial.name, "Mochi")
        XCTAssertNil(repository.activePet)
        XCTAssertFalse(repository.hasCompletedOnboarding)
        XCTAssertEqual(repository.memorials.count, 1)
    }

    func testTickAdvancesNeedsFromLastUpdatedAt() throws {
        _ = try repository.createPet(name: "Mochi", avatarConfiguration: .default)
        let pet = try XCTUnwrap(repository.activePet)
        let from = pet.state.lastUpdatedAt
        var state = pet.state
        state.lastUpdatedAt = from.addingTimeInterval(-6 * 3600)
        try repository.save(needs: pet.needs, state: state)

        let beforeHunger = repository.activePet!.needs.hunger
        let result = try repository.tick(now: from)
        guard case .updated(let updated) = result else {
            return XCTFail("Expected updated pet")
        }
        XCTAssertLessThan(updated.needs.hunger, beforeHunger)
        XCTAssertEqual(updated.state.lastUpdatedAt, from)
    }

    func testPerformCareFeedPersistsAndAppendsEvent() throws {
        _ = try repository.createPet(name: "Mochi", avatarConfiguration: .default)
        var needs = repository.activePet!.needs
        needs.hunger = 20
        try repository.save(needs: needs, state: repository.activePet!.state)

        let result = try repository.performCare(.feed, note: "breakfast")
        guard case .updated(let updated) = result else {
            return XCTFail("Expected updated pet")
        }
        XCTAssertGreaterThan(updated.needs.hunger, 20)
        let events = try repository.careEvents(for: updated.id)
        XCTAssertEqual(events.first?.type, .feed)
        XCTAssertEqual(events.first?.note, "breakfast")
    }

    func testTickPersistsLifeStageFromAge() throws {
        let createdAt = Date()
        let birthDate = createdAt.addingTimeInterval(-10 * 24 * 3600)
        _ = try repository.createPet(
            name: "Mochi",
            avatarConfiguration: .default,
            createdAt: createdAt,
            birthDate: birthDate
        )
        let result = try repository.tick(now: createdAt)
        guard case .updated(let updated) = result else {
            return XCTFail("Expected updated pet")
        }
        XCTAssertEqual(updated.lifeStage, .teenager)
    }

    func testTickMemorialisesWhenHealthReachesZero() throws {
        _ = try repository.createPet(name: "Mochi", avatarConfiguration: .default)
        let pet = try XCTUnwrap(repository.activePet)
        var needs = PetNeeds(
            hunger: 0,
            hydration: 0,
            happiness: 80,
            health: 1,
            cleanliness: 80,
            energy: 80
        )
        var state = pet.state
        let now = state.lastUpdatedAt
        state.lastUpdatedAt = now.addingTimeInterval(-72 * 3600)
        try repository.save(needs: needs, state: state)

        let result = try repository.tick(now: now)
        guard case .deceased(let memorial) = result else {
            return XCTFail("Expected deceased memorial")
        }
        XCTAssertEqual(memorial.name, "Mochi")
        XCTAssertEqual(memorial.finalCondition, "neglected")
        XCTAssertNil(repository.activePet)
        XCTAssertEqual(repository.memorials.count, 1)
    }

    func testUserDefaultsMigrationCreatesActivePet() throws {
        let suite = "tamaloci.tests.migrate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let legacy = CreatedPet(
            name: "Legacy",
            avatarConfiguration: .default,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        defaults.set(try JSONEncoder().encode(legacy), forKey: "tamaloci.createdPet")

        UserDefaultsPetMigrator.migrateIfNeeded(repository: repository, defaults: defaults)
        XCTAssertEqual(repository.activePet?.name, "Legacy")
        XCTAssertTrue(defaults.bool(forKey: "tamaloci.didMigrateCreatedPetToSwiftData"))
        XCTAssertNil(defaults.data(forKey: "tamaloci.createdPet"))
    }
}
