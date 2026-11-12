import XCTest
@testable import Tamaloci

final class AvatarConfigurationTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let original = AvatarConfiguration(
            skinTint: AvatarColor(red: 0.9, green: 0.7, blue: 0.55, alpha: 1),
            eyeScale: 1.2,
            browScale: 0.9
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AvatarConfiguration.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    @MainActor
    func testStoreSaveRestoreRoundTrip() {
        let suiteName = "tamaloci.tests.avatar.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AvatarConfigurationStore(defaults: defaults)
        let custom = AvatarConfiguration(
            skinTint: AvatarColor(red: 0.85, green: 0.65, blue: 0.5),
            eyeScale: 1.15,
            browScale: 1.1
        )
        store.save(custom)

        let restoredStore = AvatarConfigurationStore(defaults: defaults)
        XCTAssertEqual(restoredStore.restore(), custom)
    }

    @MainActor
    func testStoreRestoreAfterClearReturnsLastInMemory() {
        let suiteName = "tamaloci.tests.avatar.clear.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AvatarConfigurationStore(defaults: defaults)
        let custom = AvatarConfiguration(
            skinTint: AvatarColor(red: 0.8, green: 0.6, blue: 0.45),
            eyeScale: 1.05,
            browScale: 1.05
        )
        store.save(custom)
        store.clearPersisted()
        XCTAssertEqual(store.restore(), custom)
    }
}
