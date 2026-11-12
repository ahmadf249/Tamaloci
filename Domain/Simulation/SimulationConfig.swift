import Foundation

/// Tunable balance knobs — rates are per hour unless noted. Playtest, don’t hardcode “final.”
struct SimulationConfig: Equatable, Sendable {
    /// Drain per hour while awake.
    var hungerDrainPerHour: Double
    var hydrationDrainPerHour: Double
    var happinessDrainPerHour: Double
    var cleanlinessDrainPerHour: Double
    var energyDrainPerHour: Double

    /// Multiplier applied to hunger/hydration drain while sleeping (< 1 = slower).
    var sleepDrainMultiplier: Double
    /// Energy recovered per hour while sleeping.
    var energyRecoverPerHourSleeping: Double

    /// Care recovery deltas (absolute points on 0…100 scale).
    var feedRecovery: Double
    var waterRecovery: Double
    var playHappinessRecovery: Double
    var playEnergyCost: Double
    var cleanRecovery: Double
    var medicineHealthRecovery: Double
    var medicineClearsIllness: Bool

    /// Need ≤ this counts as critical for that meter.
    var criticalThreshold: Double
    /// Health drain per hour when ≥ `criticalNeedCountForHealthDrain` meters are critical.
    var healthDrainPerHourWhenCritical: Double
    var criticalNeedCountForHealthDrain: Int
    /// Become ill when this many needs are critical (excluding health itself).
    var criticalNeedCountForIllness: Int
    /// Health ≤ this is “critical health” for UI (no death in M4).
    var criticalHealthThreshold: Double

    static let `default` = SimulationConfig(
        hungerDrainPerHour: 4,
        hydrationDrainPerHour: 5,
        happinessDrainPerHour: 3,
        cleanlinessDrainPerHour: 2.5,
        energyDrainPerHour: 3,
        sleepDrainMultiplier: 0.4,
        energyRecoverPerHourSleeping: 8,
        feedRecovery: 28,
        waterRecovery: 30,
        playHappinessRecovery: 22,
        playEnergyCost: 10,
        cleanRecovery: 35,
        medicineHealthRecovery: 25,
        medicineClearsIllness: true,
        criticalThreshold: 25,
        healthDrainPerHourWhenCritical: 4,
        criticalNeedCountForHealthDrain: 2,
        criticalNeedCountForIllness: 2,
        criticalHealthThreshold: 30
    )
}
