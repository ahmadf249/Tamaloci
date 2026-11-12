import XCTest
@testable import Tamaloci

final class AppPreferencesTests: XCTestCase {
    private let keys = [
        AppPreferences.hapticsEnabledKey,
        AppPreferences.soundEnabledKey,
        AppPreferences.careNotificationsEnabledKey
    ]

    override func setUp() {
        super.setUp()
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func testDefaultsAreEnabled() {
        XCTAssertTrue(AppPreferences.hapticsEnabled)
        XCTAssertTrue(AppPreferences.soundEnabled)
        XCTAssertTrue(AppPreferences.careNotificationsEnabled)
    }

    func testCanDisablePrefs() {
        UserDefaults.standard.set(false, forKey: AppPreferences.hapticsEnabledKey)
        UserDefaults.standard.set(false, forKey: AppPreferences.soundEnabledKey)
        UserDefaults.standard.set(false, forKey: AppPreferences.careNotificationsEnabledKey)
        XCTAssertFalse(AppPreferences.hapticsEnabled)
        XCTAssertFalse(AppPreferences.soundEnabled)
        XCTAssertFalse(AppPreferences.careNotificationsEnabled)
    }
}
