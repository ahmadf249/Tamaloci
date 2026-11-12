import XCTest
@testable import Tamaloci

final class PetSimulationTests: XCTestCase {
    private let config = SimulationConfig.default
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testAdvanceSixHoursDrainsNeeds() {
        let start = PetNeeds.neutralDefaults
        let state = PetRuntimeState.activeDefaults
        let t1 = t0.addingTimeInterval(6 * 3600)
        let result = PetSimulation.advance(needs: start, state: state, from: t0, to: t1, config: config)

        XCTAssertLessThan(result.needs.hunger, start.hunger)
        XCTAssertLessThan(result.needs.hydration, start.hydration)
        XCTAssertLessThan(result.needs.happiness, start.happiness)
        XCTAssertLessThan(result.needs.cleanliness, start.cleanliness)
        XCTAssertLessThan(result.needs.energy, start.energy)
        XCTAssertEqual(result.state.lastUpdatedAt, t1)

        let expectedHunger = start.hunger - config.hungerDrainPerHour * 6
        XCTAssertEqual(result.needs.hunger, expectedHunger, accuracy: 0.01)
    }

    func testSleepRecoversEnergyAndSlowsHungerDrain() {
        var state = PetRuntimeState.activeDefaults
        state.isSleeping = true
        let start = PetNeeds.neutralDefaults
        let t1 = t0.addingTimeInterval(3 * 3600)
        let sleeping = PetSimulation.advance(needs: start, state: state, from: t0, to: t1, config: config)
        state.isSleeping = false
        let awake = PetSimulation.advance(needs: start, state: state, from: t0, to: t1, config: config)

        XCTAssertGreaterThan(sleeping.needs.energy, start.energy)
        XCTAssertGreaterThan(sleeping.needs.hunger, awake.needs.hunger)
    }

    func testFeedRecoversHunger() {
        var needs = PetNeeds.neutralDefaults
        needs.hunger = 20
        let result = PetSimulation.applyCare(.feed, needs: needs, state: .activeDefaults, at: t0, config: config)
        XCTAssertEqual(result.needs.hunger, min(100, 20 + config.feedRecovery), accuracy: 0.01)
    }

    func testPlayRaisesHappinessAndCostsEnergy() {
        var needs = PetNeeds.neutralDefaults
        needs.happiness = 40
        needs.energy = 50
        let result = PetSimulation.applyCare(.play, needs: needs, state: .activeDefaults, at: t0, config: config)
        XCTAssertEqual(result.needs.happiness, min(100, 40 + config.playHappinessRecovery), accuracy: 0.01)
        XCTAssertEqual(result.needs.energy, max(0, 50 - config.playEnergyCost), accuracy: 0.01)
        XCTAssertFalse(result.state.isSleeping)
    }

    func testMedicineClearsIllnessAndBoostsHealth() {
        var needs = PetNeeds.neutralDefaults
        needs.health = 40
        var state = PetRuntimeState.activeDefaults
        state.isIll = true
        let result = PetSimulation.applyCare(.medicine, needs: needs, state: state, at: t0, config: config)
        XCTAssertFalse(result.state.isIll)
        XCTAssertEqual(result.needs.health, min(100, 40 + config.medicineHealthRecovery), accuracy: 0.01)
    }

    func testCriticalNeedsCauseIllnessAndHealthDrain() {
        var needs = PetNeeds(
            hunger: 10,
            hydration: 10,
            happiness: 80,
            health: 80,
            cleanliness: 80,
            energy: 80
        )
        let t1 = t0.addingTimeInterval(2 * 3600)
        let result = PetSimulation.advance(needs: needs, state: .activeDefaults, from: t0, to: t1, config: config)
        XCTAssertTrue(result.state.isIll)
        XCTAssertLessThan(result.needs.health, 80)
    }

    func testAdvanceNeverSetsDeceasedInM4() {
        var needs = PetNeeds.neutralDefaults
        needs.health = 1
        needs.hunger = 0
        needs.hydration = 0
        let t1 = t0.addingTimeInterval(48 * 3600)
        let result = PetSimulation.advance(needs: needs, state: .activeDefaults, from: t0, to: t1, config: config)
        XCTAssertEqual(result.state.lifecycleStatus, .active)
    }

    func testSuggestedExpressionForHungry() {
        var needs = PetNeeds.neutralDefaults
        needs.hunger = 10
        XCTAssertEqual(PetSimulation.suggestedExpression(needs: needs, state: .activeDefaults), .hungry)
    }
}
