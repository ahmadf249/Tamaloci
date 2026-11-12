import Foundation

/// Appearance parameters for the pet head. Pure domain type so it can be
/// saved/restored independently of RealityKit (SwiftData comes in M3).
struct AvatarConfiguration: Equatable, Codable, Sendable {
    var skinTint: AvatarColor
    var hairColor: AvatarColor
    var irisColor: AvatarColor
    /// Uniform eye scale relative to the procedural baseline (1.0 = default).
    var eyeScale: Float
    /// Horizontal brow scale relative to the procedural baseline (1.0 = default).
    var browScale: Float
    /// Skull X scale (1.0 = default).
    var headWidth: Float
    /// Lower-face / jaw emphasis (1.0 = default).
    var jawWidth: Float
    /// Half-distance multiplier for eye X positions (1.0 = default).
    var eyeSpacing: Float
    /// Nose uniform scale (1.0 = default).
    var noseScale: Float
    /// Mouth width scale (1.0 = default).
    var mouthWidth: Float
    /// Vertical face length (skull Y). 1.0 = default.
    var faceLength: Float
    /// 0 = very short / thin hair, 1 = full crown coverage.
    var hairCoverage: Float

    static let `default` = AvatarConfiguration(
        skinTint: AvatarColor(red: 0.96, green: 0.80, blue: 0.70),
        hairColor: AvatarColor(red: 0.22, green: 0.14, blue: 0.10),
        irisColor: AvatarColor(red: 0.28, green: 0.45, blue: 0.72),
        eyeScale: 1.0,
        browScale: 1.0,
        headWidth: 1.0,
        jawWidth: 1.0,
        eyeSpacing: 1.0,
        noseScale: 1.0,
        mouthWidth: 1.0,
        faceLength: 1.0,
        hairCoverage: 0.85
    )

    /// Clamp morphs into safe stylized ranges for capture/editor.
    func clamped() -> AvatarConfiguration {
        AvatarConfiguration(
            skinTint: skinTint.clampedChannel(),
            hairColor: hairColor.clampedChannel(),
            irisColor: irisColor.clampedChannel(),
            eyeScale: eyeScale.clamped(to: 0.75...1.35),
            browScale: browScale.clamped(to: 0.7...1.4),
            headWidth: headWidth.clamped(to: 0.85...1.2),
            jawWidth: jawWidth.clamped(to: 0.85...1.25),
            eyeSpacing: eyeSpacing.clamped(to: 0.8...1.25),
            noseScale: noseScale.clamped(to: 0.75...1.35),
            mouthWidth: mouthWidth.clamped(to: 0.75...1.4),
            faceLength: faceLength.clamped(to: 0.9...1.15),
            hairCoverage: hairCoverage.clamped(to: 0.15...1.0)
        )
    }

    enum CodingKeys: String, CodingKey {
        case skinTint, hairColor, irisColor
        case eyeScale, browScale
        case headWidth, jawWidth, eyeSpacing, noseScale, mouthWidth
        case faceLength, hairCoverage
    }

    init(
        skinTint: AvatarColor,
        hairColor: AvatarColor = AvatarConfiguration.default.hairColor,
        irisColor: AvatarColor = AvatarConfiguration.default.irisColor,
        eyeScale: Float,
        browScale: Float,
        headWidth: Float = 1,
        jawWidth: Float = 1,
        eyeSpacing: Float = 1,
        noseScale: Float = 1,
        mouthWidth: Float = 1,
        faceLength: Float = 1,
        hairCoverage: Float = 0.85
    ) {
        self.skinTint = skinTint
        self.hairColor = hairColor
        self.irisColor = irisColor
        self.eyeScale = eyeScale
        self.browScale = browScale
        self.headWidth = headWidth
        self.jawWidth = jawWidth
        self.eyeSpacing = eyeSpacing
        self.noseScale = noseScale
        self.mouthWidth = mouthWidth
        self.faceLength = faceLength
        self.hairCoverage = hairCoverage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skinTint = try container.decode(AvatarColor.self, forKey: .skinTint)
        hairColor = try container.decodeIfPresent(AvatarColor.self, forKey: .hairColor) ?? Self.default.hairColor
        irisColor = try container.decodeIfPresent(AvatarColor.self, forKey: .irisColor) ?? Self.default.irisColor
        eyeScale = try container.decode(Float.self, forKey: .eyeScale)
        browScale = try container.decode(Float.self, forKey: .browScale)
        headWidth = try container.decodeIfPresent(Float.self, forKey: .headWidth) ?? 1
        jawWidth = try container.decodeIfPresent(Float.self, forKey: .jawWidth) ?? 1
        eyeSpacing = try container.decodeIfPresent(Float.self, forKey: .eyeSpacing) ?? 1
        noseScale = try container.decodeIfPresent(Float.self, forKey: .noseScale) ?? 1
        mouthWidth = try container.decodeIfPresent(Float.self, forKey: .mouthWidth) ?? 1
        faceLength = try container.decodeIfPresent(Float.self, forKey: .faceLength) ?? 1
        hairCoverage = try container.decodeIfPresent(Float.self, forKey: .hairCoverage) ?? 0.85
    }
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

    func clampedChannel() -> AvatarColor {
        AvatarColor(
            red: red.clamped01(),
            green: green.clamped01(),
            blue: blue.clamped01(),
            alpha: alpha.clamped01()
        )
    }

    /// Blend toward a stylized palette so camera noise doesn’t look muddy.
    func stylized(toward reference: AvatarColor, amount: Double) -> AvatarColor {
        let t = amount.clamped01()
        return AvatarColor(
            red: (red * (1 - t) + reference.red * t).clamped01(),
            green: (green * (1 - t) + reference.green * t).clamped01(),
            blue: (blue * (1 - t) + reference.blue * t).clamped01(),
            alpha: alpha
        )
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped01() -> Double {
        min(max(self, 0), 1)
    }
}
