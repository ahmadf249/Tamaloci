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
    /// Health ≤ this is “critical health” for UI.
    var criticalHealthThreshold: Double
    /// Health ≤ this after advance → deceased (M5).
    var deathHealthThreshold: Double

    /// Age days (from birth) at which each stage begins.
    var childAgeDays: Int
    var teenagerAgeDays: Int
    var adultAgeDays: Int

    /// Auto-sleep when awake and energy ≤ this; auto-wake when sleeping and energy ≥ this.
    var autoSleepEnergyThreshold: Double
    var autoWakeEnergyThreshold: Double

    /// Environment snapshot older than this is ignored (neutral rates).
    var environmentMaxAgeHours: Double
    /// Temp above this (°C) multiplies hydration drain.
    var hotTemperatureCelsius: Double
    var hotHydrationDrainMultiplier: Double
    /// Temp below this (°C) multiplies happiness drain.
    var coldTemperatureCelsius: Double
    var coldHappinessDrainMultiplier: Double

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
        criticalHealthThreshold: 30,
        deathHealthThreshold: 0,
        childAgeDays: 3,
        teenagerAgeDays: 7,
        adultAgeDays: 14,
        autoSleepEnergyThreshold: 0,
        autoWakeEnergyThreshold: 80,
        environmentMaxAgeHours: 6,
        hotTemperatureCelsius: 28,
        hotHydrationDrainMultiplier: 1.25,
        coldTemperatureCelsius: 10,
        coldHappinessDrainMultiplier: 1.15
    )
}
