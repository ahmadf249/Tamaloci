import Foundation

/// Stub for PDF §7.3 — Phase I does not simulate needs yet.
struct PetNeeds: Equatable, Sendable {
    var hunger: Double
    var hydration: Double
    var happiness: Double
    var health: Double
    var cleanliness: Double
    var energy: Double

    static let neutralDefaults = PetNeeds(
        hunger: 80,
        hydration: 80,
        happiness: 80,
        health: 100,
        cleanliness: 80,
        energy: 80
    )
}
