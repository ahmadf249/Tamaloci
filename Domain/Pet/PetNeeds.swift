import Foundation

/// Need meters — persisted in M3; simulated in M4.
struct PetNeeds: Equatable, Codable, Sendable {
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
