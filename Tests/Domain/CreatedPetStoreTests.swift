import XCTest
@testable import Tamaloci

@MainActor
final class CreatedPetStoreTests: XCTestCase {
    func testSaveRestoreRoundTrip() {
        let suite = "tamaloci.tests.pet.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = CreatedPetStore(defaults: defaults)
        XCTAssertFalse(store.hasCompletedOnboarding)

        let pet = CreatedPet(
            name: "Mochi",
            avatarConfiguration: .default,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        store.save(pet)
        XCTAssertTrue(store.hasCompletedOnboarding)

        let restored = CreatedPetStore(defaults: defaults)
        XCTAssertEqual(restored.restore()?.name, "Mochi")
        XCTAssertTrue(restored.hasCompletedOnboarding)
    }

    func testEmptyNameDoesNotCountAsCompleted() {
        let pet = CreatedPet(name: "   ", avatarConfiguration: .default, createdAt: Date())
        XCTAssertFalse(pet.hasCompletedOnboarding)
    }
}
