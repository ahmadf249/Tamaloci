import XCTest
@testable import Tamaloci

/// Pure-domain fallbacks that device services feed into (no WeatherKit/UIKit required).
final class DeviceFallbackTests: XCTestCase {
    private let config = SimulationConfig.default
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testNilWeatherContextMatchesEmptyContext() {
        let t1 = t0.addingTimeInterval(3 * 3600)
        let withNilEnv = PetSimulation.advance(
            needs: .neutralDefaults,
            state: .activeDefaults,
            lifeStage: .baby,
            birthDate: t0,
            from: t0,
            to: t1,
            config: config,
            context: SimulationContext(environment: nil, batteryCharging: nil)
        )
        let empty = PetSimulation.advance(
            needs: .neutralDefaults,
            state: .activeDefaults,
            lifeStage: .baby,
            birthDate: t0,
            from: t0,
            to: t1,
            config: config,
            context: .empty
        )
        XCTAssertEqual(withNilEnv.needs, empty.needs)
        XCTAssertEqual(withNilEnv.state.isSleeping, empty.state.isSleeping)
    }

    func testUnknownBatteryDoesNotOverrideManualSleep() {
        var state = PetRuntimeState.activeDefaults
        state.isSleeping = true
        state.sleepSource = .manual
        var needs = PetNeeds.neutralDefaults
        needs.energy = 40
        let t1 = t0.addingTimeInterval(3600)
        let result = PetSimulation.advance(
            needs: needs,
            state: state,
            lifeStage: .baby,
            birthDate: t0,
            from: t0,
            to: t1,
            config: config,
            context: SimulationContext(environment: nil, batteryCharging: nil)
        )
        XCTAssertTrue(result.state.isSleeping)
        XCTAssertEqual(result.state.sleepSource, .manual)
    }

    func testCareNotificationsPrefOffIsReadable() {
        UserDefaults.standard.set(false, forKey: AppPreferences.careNotificationsEnabledKey)
        defer { UserDefaults.standard.removeObject(forKey: AppPreferences.careNotificationsEnabledKey) }
        XCTAssertFalse(AppPreferences.careNotificationsEnabled)
    }
}
