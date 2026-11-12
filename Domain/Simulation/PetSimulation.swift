import Foundation

/// Pure pet simulation — no SwiftUI / RealityKit / SwiftData / WeatherKit / UIKit.
enum PetSimulation {
    struct Snapshot: Equatable, Sendable {
        var needs: PetNeeds
        var state: PetRuntimeState
        var lifeStage: PetLifeStage
    }

    /// Advance needs/state/stage from `from` to `to` using elapsed-time math.
    static func advance(
        needs: PetNeeds,
        state: PetRuntimeState,
        lifeStage: PetLifeStage,
        birthDate: Date,
        from: Date,
        to: Date,
        config: SimulationConfig = .default,
        context: SimulationContext = .empty
    ) -> Snapshot {
        let ageDays = ageDays(birthDate: birthDate, asOf: to)
        let resolvedStage = max(lifeStage, stage(forAgeDays: ageDays, config: config))

        let elapsed = max(to.timeIntervalSince(from), 0)
        guard elapsed > 0 else {
            var nextState = reconcileBattery(state: state, context: context, at: to)
            nextState.lastUpdatedAt = max(state.lastUpdatedAt, to)
            return Snapshot(needs: needs.clamped(), state: nextState, lifeStage: resolvedStage)
        }

        if state.lifecycleStatus == .deceased {
            var nextState = state
            nextState.lastUpdatedAt = to
            return Snapshot(needs: needs.clamped(), state: nextState, lifeStage: resolvedStage)
        }

        let hours = elapsed / 3600.0
        var nextNeeds = needs
        var nextState = state

        let envFactors = environmentDrainFactors(context: context, asOf: to, config: config)
        let sleepMul = nextState.isSleeping ? config.sleepDrainMultiplier : 1.0
        nextNeeds.hunger -= config.hungerDrainPerHour * hours * sleepMul
        nextNeeds.hydration -= config.hydrationDrainPerHour * hours * sleepMul * envFactors.hydration
        nextNeeds.happiness -= config.happinessDrainPerHour * hours * envFactors.happiness
        nextNeeds.cleanliness -= config.cleanlinessDrainPerHour * hours

        if nextState.isSleeping {
            nextNeeds.energy += config.energyRecoverPerHourSleeping * hours
        } else {
            nextNeeds.energy -= config.energyDrainPerHour * hours
        }

        nextNeeds = nextNeeds.clamped()
        let criticalCount = criticalNeedCount(nextNeeds, threshold: config.criticalThreshold)
        if criticalCount >= config.criticalNeedCountForHealthDrain {
            nextNeeds.health -= config.healthDrainPerHourWhenCritical * hours
        }
        nextNeeds = nextNeeds.clamped()

        if criticalCount >= config.criticalNeedCountForIllness {
            nextState.isIll = true
        }

        // Auto sleep / wake from energy (battery reconcile happens after).
        if !nextState.isSleeping, nextNeeds.energy <= config.autoSleepEnergyThreshold {
            nextState.isSleeping = true
            if nextState.sleepSource != .charging {
                nextState.sleepSource = .scheduled
            }
        } else if nextState.isSleeping,
                  nextState.sleepSource != .charging,
                  nextNeeds.energy >= config.autoWakeEnergyThreshold {
            nextState.isSleeping = false
            nextState.sleepSource = .manual
        }

        nextState = reconcileBattery(state: nextState, context: context, at: to)

        if nextNeeds.health <= config.deathHealthThreshold {
            nextState.lifecycleStatus = .deceased
            nextState.isSleeping = false
            nextState.sleepSource = .manual
            nextState.conditionSummary = "neglected"
        } else {
            nextState.lifecycleStatus = .active
            nextState.conditionSummary = conditionSummary(needs: nextNeeds, state: nextState, config: config)
        }
        nextState.lastUpdatedAt = to

        return Snapshot(needs: nextNeeds, state: nextState, lifeStage: resolvedStage)
    }

    /// Apply a care action (does not append history — caller persists). Does not cause death.
    static func applyCare(
        _ type: CareEventType,
        needs: PetNeeds,
        state: PetRuntimeState,
        lifeStage: PetLifeStage,
        at date: Date = Date(),
        config: SimulationConfig = .default
    ) -> Snapshot {
        var nextNeeds = needs
        var nextState = state

        switch type {
        case .feed:
            nextNeeds.hunger += config.feedRecovery
            nextNeeds.happiness += 4
        case .water:
            nextNeeds.hydration += config.waterRecovery
        case .play:
            nextNeeds.happiness += config.playHappinessRecovery
            nextNeeds.energy -= config.playEnergyCost
            nextState.isSleeping = false
            nextState.sleepSource = .manual
        case .clean:
            nextNeeds.cleanliness += config.cleanRecovery
        case .medicine:
            nextNeeds.health += config.medicineHealthRecovery
            if config.medicineClearsIllness {
                nextState.isIll = false
            }
        case .sleep:
            nextState.isSleeping = true
            nextState.sleepSource = .manual
        case .wake:
            nextState.isSleeping = false
            nextState.sleepSource = .manual
        }

        nextNeeds = nextNeeds.clamped()
        if nextState.lifecycleStatus != .deceased {
            nextState.lifecycleStatus = .active
            nextState.conditionSummary = conditionSummary(needs: nextNeeds, state: nextState, config: config)
        }
        nextState.lastUpdatedAt = date
        return Snapshot(needs: nextNeeds, state: nextState, lifeStage: lifeStage)
    }

    static func stage(forAgeDays ageDays: Int, config: SimulationConfig = .default) -> PetLifeStage {
        if ageDays >= config.adultAgeDays { return .adult }
        if ageDays >= config.teenagerAgeDays { return .teenager }
        if ageDays >= config.childAgeDays { return .child }
        return .baby
    }

    static func ageDays(birthDate: Date, asOf date: Date) -> Int {
        max(Calendar.current.dateComponents([.day], from: birthDate, to: date).day ?? 0, 0)
    }

    static func suggestedExpression(needs: PetNeeds, state: PetRuntimeState, config: SimulationConfig = .default) -> PetExpression {
        if state.lifecycleStatus == .deceased {
            return .deceased
        }
        if state.isIll || needs.health <= config.criticalHealthThreshold {
            return .sick
        }
        if state.isSleeping || needs.energy <= config.criticalThreshold {
            return .sleepy
        }
        if needs.hunger <= config.criticalThreshold {
            return .hungry
        }
        if needs.happiness <= config.criticalThreshold {
            return .sad
        }
        if needs.happiness >= 75 && needs.health >= 70 {
            return .happy
        }
        return .neutral
    }

    static func isCritical(needs: PetNeeds, config: SimulationConfig = .default) -> Bool {
        needs.health <= config.criticalHealthThreshold
            || criticalNeedCount(needs, threshold: config.criticalThreshold) >= 1
    }

    // MARK: - Helpers

    private struct EnvDrainFactors {
        var hydration: Double
        var happiness: Double
    }

    private static func environmentDrainFactors(
        context: SimulationContext,
        asOf date: Date,
        config: SimulationConfig
    ) -> EnvDrainFactors {
        guard let env = context.environment,
              let temp = env.temperatureCelsius,
              let captured = env.capturedAt
        else {
            return EnvDrainFactors(hydration: 1, happiness: 1)
        }
        let ageHours = date.timeIntervalSince(captured) / 3600.0
        guard ageHours >= 0, ageHours <= config.environmentMaxAgeHours else {
            return EnvDrainFactors(hydration: 1, happiness: 1)
        }
        var hydration: Double = 1
        var happiness: Double = 1
        if temp > config.hotTemperatureCelsius {
            hydration = config.hotHydrationDrainMultiplier
        }
        if temp < config.coldTemperatureCelsius {
            happiness = config.coldHappinessDrainMultiplier
        }
        return EnvDrainFactors(hydration: hydration, happiness: happiness)
    }

    /// Apply only currently observed charging — does not invent mid-absence unplug times.
    private static func reconcileBattery(
        state: PetRuntimeState,
        context: SimulationContext,
        at date: Date
    ) -> PetRuntimeState {
        var next = state
        guard let charging = context.batteryCharging else { return next }
        if charging {
            next.isSleeping = true
            next.sleepSource = .charging
        } else if next.sleepSource == .charging {
            next.isSleeping = false
            next.sleepSource = .manual
        }
        _ = date
        return next
    }

    private static func criticalNeedCount(_ needs: PetNeeds, threshold: Double) -> Int {
        [
            needs.hunger,
            needs.hydration,
            needs.happiness,
            needs.cleanliness,
            needs.energy
        ].filter { $0 <= threshold }.count
    }

    private static func conditionSummary(
        needs: PetNeeds,
        state: PetRuntimeState,
        config: SimulationConfig
    ) -> String {
        if state.lifecycleStatus == .deceased { return "neglected" }
        if state.isIll { return "ill" }
        if needs.health <= config.criticalHealthThreshold { return "critical" }
        if state.isSleeping { return "sleeping" }
        if needs.hunger <= config.criticalThreshold { return "hungry" }
        if needs.hydration <= config.criticalThreshold { return "thirsty" }
        if needs.cleanliness <= config.criticalThreshold { return "dirty" }
        if needs.energy <= config.criticalThreshold { return "tired" }
        if needs.happiness <= config.criticalThreshold { return "sad" }
        return "healthy"
    }
}

extension PetNeeds {
    func clamped() -> PetNeeds {
        PetNeeds(
            hunger: hunger.clamped01to100(),
            hydration: hydration.clamped01to100(),
            happiness: happiness.clamped01to100(),
            health: health.clamped01to100(),
            cleanliness: cleanliness.clamped01to100(),
            energy: energy.clamped01to100()
        )
    }
}

private extension Double {
    func clamped01to100() -> Double {
        min(max(self, 0), 100)
    }
}
