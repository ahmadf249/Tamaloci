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
