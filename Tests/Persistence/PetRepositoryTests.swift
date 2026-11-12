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
        let updated = try repository.tick(now: from)
        XCTAssertLessThan(updated.needs.hunger, beforeHunger)
        XCTAssertEqual(updated.state.lastUpdatedAt, from)
    }

    func testPerformCareFeedPersistsAndAppendsEvent() throws {
        _ = try repository.createPet(name: "Mochi", avatarConfiguration: .default)
        var needs = repository.activePet!.needs
        needs.hunger = 20
        try repository.save(needs: needs, state: repository.activePet!.state)

        let updated = try repository.performCare(.feed, note: "breakfast")
        XCTAssertGreaterThan(updated.needs.hunger, 20)
        let events = try repository.careEvents(for: updated.id)
        XCTAssertEqual(events.first?.type, .feed)
        XCTAssertEqual(events.first?.note, "breakfast")
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
