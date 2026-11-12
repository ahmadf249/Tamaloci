import Foundation

/// Appearance parameters for the pet head. Pure domain type so it can be
/// saved/restored independently of RealityKit (M1.3; SwiftData comes in M3).
struct AvatarConfiguration: Equatable, Codable, Sendable {
    var skinTint: AvatarColor
    /// Uniform eye scale relative to the procedural baseline (1.0 = default).
    var eyeScale: Float
    /// Horizontal brow scale relative to the procedural baseline (1.0 = default).
    var browScale: Float

    static let `default` = AvatarConfiguration(
        skinTint: AvatarColor(red: 0.96, green: 0.80, blue: 0.70),
        eyeScale: 1.0,
        browScale: 1.0
    )
}

struct AvatarColor: Equatable, Codable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}
