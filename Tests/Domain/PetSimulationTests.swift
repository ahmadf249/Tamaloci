import XCTest
@testable import Tamaloci

final class PetSimulationTests: XCTestCase {
    private let config = SimulationConfig.default
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testAdvanceSixHoursDrainsNeeds() {
        let start = PetNeeds.neutralDefaults
        let state = PetRuntimeState.activeDefaults
        let t1 = t0.addingTimeInterval(6 * 3600)
        let result = PetSimulation.advance(
            needs: start,
            state: state,
            lifeStage: .baby,
            birthDate: t0,
            from: t0,
            to: t1,
            config: config
        )

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
        let sleeping = PetSimulation.advance(
            needs: start, state: state, lifeStage: .baby, birthDate: t0, from: t0, to: t1, config: config
        )
        state.isSleeping = false
        let awake = PetSimulation.advance(
            needs: start, state: state, lifeStage: .baby, birthDate: t0, from: t0, to: t1, config: config
        )

        XCTAssertGreaterThan(sleeping.needs.energy, start.energy)
        XCTAssertGreaterThan(sleeping.needs.hunger, awake.needs.hunger)
    }

    func testFeedRecoversHunger() {
        var needs = PetNeeds.neutralDefaults
        needs.hunger = 20
        let result = PetSimulation.applyCare(
            .feed, needs: needs, state: .activeDefaults, lifeStage: .baby, at: t0, config: config
        )
        XCTAssertEqual(result.needs.hunger, min(100, 20 + config.feedRecovery), accuracy: 0.01)
    }

    func testPlayRaisesHappinessAndCostsEnergy() {
        var needs = PetNeeds.neutralDefaults
        needs.happiness = 40
        needs.energy = 50
        let result = PetSimulation.applyCare(
            .play, needs: needs, state: .activeDefaults, lifeStage: .baby, at: t0, config: config
        )
        XCTAssertEqual(result.needs.happiness, min(100, 40 + config.playHappinessRecovery), accuracy: 0.01)
        XCTAssertEqual(result.needs.energy, max(0, 50 - config.playEnergyCost), accuracy: 0.01)
        XCTAssertFalse(result.state.isSleeping)
    }

    func testMedicineClearsIllnessAndBoostsHealth() {
        var needs = PetNeeds.neutralDefaults
        needs.health = 40
        var state = PetRuntimeState.activeDefaults
        state.isIll = true
        let result = PetSimulation.applyCare(
            .medicine, needs: needs, state: state, lifeStage: .baby, at: t0, config: config
        )
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
        let result = PetSimulation.advance(
            needs: needs, state: .activeDefaults, lifeStage: .baby, birthDate: t0, from: t0, to: t1, config: config
        )
        XCTAssertTrue(result.state.isIll)
        XCTAssertLessThan(result.needs.health, 80)
    }

    func testAdvanceSetsDeceasedWhenHealthReachesZero() {
        var needs = PetNeeds.neutralDefaults
        needs.health = 1
        needs.hunger = 0
        needs.hydration = 0
        let t1 = t0.addingTimeInterval(48 * 3600)
        let result = PetSimulation.advance(
            needs: needs, state: .activeDefaults, lifeStage: .baby, birthDate: t0, from: t0, to: t1, config: config
        )
        XCTAssertEqual(result.state.lifecycleStatus, .deceased)
        XCTAssertEqual(result.state.conditionSummary, "neglected")
        XCTAssertEqual(result.needs.health, 0, accuracy: 0.01)
    }

    func testLifeStageAdvancesWithAgeDays() {
        XCTAssertEqual(PetSimulation.stage(forAgeDays: 0, config: config), .baby)
        XCTAssertEqual(PetSimulation.stage(forAgeDays: 3, config: config), .child)
        XCTAssertEqual(PetSimulation.stage(forAgeDays: 7, config: config), .teenager)
        XCTAssertEqual(PetSimulation.stage(forAgeDays: 14, config: config), .adult)

        let birth = t0.addingTimeInterval(-10 * 24 * 3600)
        let result = PetSimulation.advance(
            needs: .neutralDefaults,
            state: .activeDefaults,
            lifeStage: .baby,
            birthDate: birth,
            from: t0,
            to: t0.addingTimeInterval(3600),
            config: config
        )
        XCTAssertEqual(result.lifeStage, .teenager)
    }

    func testAutoSleepWhenEnergyDepletes() {
        var needs = PetNeeds.neutralDefaults
        needs.energy = 2
        let hours = 2.0
        let t1 = t0.addingTimeInterval(hours * 3600)
        let result = PetSimulation.advance(
            needs: needs, state: .activeDefaults, lifeStage: .baby, birthDate: t0, from: t0, to: t1, config: config
        )
        XCTAssertEqual(result.needs.energy, 0, accuracy: 0.01)
        XCTAssertTrue(result.state.isSleeping)
    }

    func testAutoWakeWhenEnergyRecoversWhileSleeping() {
        var needs = PetNeeds.neutralDefaults
        needs.energy = 70
        var state = PetRuntimeState.activeDefaults
        state.isSleeping = true
        let t1 = t0.addingTimeInterval(2 * 3600)
        let result = PetSimulation.advance(
            needs: needs, state: state, lifeStage: .baby, birthDate: t0, from: t0, to: t1, config: config
        )
        XCTAssertGreaterThanOrEqual(result.needs.energy, config.autoWakeEnergyThreshold)
        XCTAssertFalse(result.state.isSleeping)
    }

    func testCareDoesNotSetDeceased() {
        var needs = PetNeeds.neutralDefaults
        needs.health = 0
        let result = PetSimulation.applyCare(
            .feed, needs: needs, state: .activeDefaults, lifeStage: .baby, at: t0, config: config
        )
        XCTAssertEqual(result.state.lifecycleStatus, .active)
    }

    func testSuggestedExpressionForHungry() {
        var needs = PetNeeds.neutralDefaults
        needs.hunger = 10
        XCTAssertEqual(PetSimulation.suggestedExpression(needs: needs, state: .activeDefaults), .hungry)
    }

    func testSuggestedExpressionForDeceased() {
        var state = PetRuntimeState.activeDefaults
        state.lifecycleStatus = .deceased
        XCTAssertEqual(PetSimulation.suggestedExpression(needs: .neutralDefaults, state: state), .deceased)
    }
}
