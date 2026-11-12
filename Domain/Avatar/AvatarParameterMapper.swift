import Foundation

/// Maps capture estimates (ARKit / Vision / manual) into bounded stylized params.
/// Never consumes raw face mesh geometry as the pet — likeness is parametric.
enum AvatarParameterMapper {
    struct FaceEstimate: Equatable, Sendable {
        var faceWidth: Float
        var jawWidth: Float
        var eyeSpacing: Float
        var eyeSize: Float
        var browScale: Float
        var noseScale: Float
        var mouthWidth: Float
        var faceLength: Float
        var hairCoverage: Float
        var skinTint: AvatarColor?
        var hairColor: AvatarColor?
        var irisColor: AvatarColor?

        static let average = FaceEstimate(
            faceWidth: 1,
            jawWidth: 1,
            eyeSpacing: 1,
            eyeSize: 1,
            browScale: 1,
            noseScale: 1,
            mouthWidth: 1,
            faceLength: 1,
            hairCoverage: 0.85,
            skinTint: nil,
            hairColor: nil,
            irisColor: nil
        )
    }

    static func makeConfiguration(from estimate: FaceEstimate, base: AvatarConfiguration = .default) -> AvatarConfiguration {
        var config = base
        config.headWidth = estimate.faceWidth
        config.jawWidth = estimate.jawWidth
        config.eyeSpacing = estimate.eyeSpacing
        config.eyeScale = estimate.eyeSize
        config.browScale = estimate.browScale
        config.noseScale = estimate.noseScale
        config.mouthWidth = estimate.mouthWidth
        config.faceLength = estimate.faceLength
        config.hairCoverage = estimate.hairCoverage
        if let skin = estimate.skinTint {
            config.skinTint = skin.stylized(toward: .init(red: 0.96, green: 0.80, blue: 0.70), amount: 0.25)
        }
        if let hair = estimate.hairColor {
            config.hairColor = hair
        }
        if let iris = estimate.irisColor {
            config.irisColor = iris
        }
        return config.clamped()
    }

    /// Merge a newer live sample into a running estimate (EMA) for stable likeness.
    static func blend(_ previous: FaceEstimate, with next: FaceEstimate, amount: Float = 0.35) -> FaceEstimate {
        let t = amount
        func mix(_ a: Float, _ b: Float) -> Float { a + (b - a) * t }
        func mixColor(_ a: AvatarColor?, _ b: AvatarColor?) -> AvatarColor? {
            guard let b else { return a }
            guard let a else { return b }
            return AvatarColor(
                red: a.red + (b.red - a.red) * Double(t),
                green: a.green + (b.green - a.green) * Double(t),
                blue: a.blue + (b.blue - a.blue) * Double(t),
                alpha: 1
            )
        }
        return FaceEstimate(
            faceWidth: mix(previous.faceWidth, next.faceWidth),
            jawWidth: mix(previous.jawWidth, next.jawWidth),
            eyeSpacing: mix(previous.eyeSpacing, next.eyeSpacing),
            eyeSize: mix(previous.eyeSize, next.eyeSize),
            browScale: mix(previous.browScale, next.browScale),
            noseScale: mix(previous.noseScale, next.noseScale),
            mouthWidth: mix(previous.mouthWidth, next.mouthWidth),
            faceLength: mix(previous.faceLength, next.faceLength),
            hairCoverage: mix(previous.hairCoverage, next.hairCoverage),
            skinTint: mixColor(previous.skinTint, next.skinTint),
            hairColor: mixColor(previous.hairColor, next.hairColor),
            irisColor: mixColor(previous.irisColor, next.irisColor)
        )
    }
}
