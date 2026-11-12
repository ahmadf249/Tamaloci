import Foundation

/// Optional device/environment inputs for a tick — pure data, no Apple frameworks.
struct SimulationContext: Equatable, Sendable {
    var environment: EnvironmentSnapshotRecord?
    /// `nil` = unknown / ignore battery this tick.
    var batteryCharging: Bool?

    static let empty = SimulationContext(environment: nil, batteryCharging: nil)
}
