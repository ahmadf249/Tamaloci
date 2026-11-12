import RealityKit
import UIKit

/// Builds a stylized Memoji-inspired floating head from primitives (App Store–safe;
/// not Apple Memoji). Driven by likeness params from ARKit/Vision capture.
enum ProceduralHeadBuilder {
    static let headName = "headRoot"
    static let skullName = "skull"
    static let leftEyeName = "leftEye"
    static let rightEyeName = "rightEye"
    static let leftLidName = "leftLid"
    static let rightLidName = "rightLid"
    static let leftBrowName = "leftBrow"
    static let rightBrowName = "rightBrow"
    static let mouthName = "mouth"
    static let noseName = "nose"
    static let hairName = "hair"
    static let hairCrownName = "hairCrown"
    static let leftCheekName = "leftCheek"
    static let rightCheekName = "rightCheek"

    static let leftEyeRestX: Float = -0.038
    static let rightEyeRestX: Float = 0.038
    static let eyeRestY: Float = 0.028
    static let eyeRestZ: Float = 0.108

    static func makeHead(configuration: AvatarConfiguration = .default) -> Entity {
        let config = configuration.clamped()
        let root = Entity()
        root.name = headName
        let skin = config.skinTint.uiColor
        let hairColor = config.hairColor.uiColor

        let skull = ModelEntity(
            mesh: .generateSphere(radius: 0.125),
            materials: [skinMaterial(skin, roughness: 0.42)]
        )
        skull.name = skullName
        skull.scale = [
            config.headWidth * 0.95,
            1.02 * config.faceLength,
            mix(0.92, config.jawWidth, t: 0.4)
        ]
        root.addChild(skull)

        // Full crown dome — covers the bald “bowl” hole of a thin side ring.
        let crown = ModelEntity(
            mesh: .generateSphere(radius: 0.126),
            materials: [SimpleMaterial(color: hairColor, roughness: .float(0.68), isMetallic: false)]
        )
        crown.name = hairCrownName
        crown.position = [0, 0.055 * config.faceLength, -0.005]
        let crownCover = 0.55 + config.hairCoverage * 0.45
        crown.scale = [
            config.headWidth * (0.92 + config.hairCoverage * 0.08),
            crownCover * 0.75,
            0.9 + config.hairCoverage * 0.08
        ]
        crown.isEnabled = config.hairCoverage > 0.2
        root.addChild(crown)

        // Side / back volume.
        let hair = ModelEntity(
            mesh: .generateSphere(radius: 0.132),
            materials: [SimpleMaterial(color: hairColor, roughness: .float(0.72), isMetallic: false)]
        )
        hair.name = hairName
        hair.position = [0, 0.02 * config.faceLength, -0.02]
        hair.scale = [
            config.headWidth * (0.98 + config.hairCoverage * 0.04),
            0.55 + config.hairCoverage * 0.35,
            0.95
        ]
        hair.isEnabled = config.hairCoverage > 0.15
        root.addChild(hair)

        root.addChild(makeEar(name: "leftEar", x: -0.118 * config.headWidth, skin: skin))
        root.addChild(makeEar(name: "rightEar", x: 0.118 * config.headWidth, skin: skin))

        let blush = skin.blended(toward: UIColor(red: 1, green: 0.55, blue: 0.55, alpha: 1), amount: 0.18)
        let leftCheek = ModelEntity(
            mesh: .generateSphere(radius: 0.028),
            materials: [skinMaterial(blush, roughness: 0.5)]
        )
        leftCheek.name = leftCheekName
        leftCheek.position = [-0.055 * config.headWidth, -0.015, 0.095]
        leftCheek.scale = [1.1, 0.85, 0.7]
        root.addChild(leftCheek)

        let rightCheek = ModelEntity(
            mesh: .generateSphere(radius: 0.028),
            materials: [skinMaterial(blush, roughness: 0.5)]
        )
        rightCheek.name = rightCheekName
        rightCheek.position = [0.055 * config.headWidth, -0.015, 0.095]
        rightCheek.scale = [1.1, 0.85, 0.7]
        root.addChild(rightCheek)

        let leftEye = makeEye(iris: config.irisColor.uiColor)
        leftEye.name = leftEyeName
        leftEye.position = [leftEyeRestX * config.eyeSpacing, eyeRestY, eyeRestZ]
        leftEye.scale = SIMD3<Float>(repeating: config.eyeScale)
        root.addChild(leftEye)

        let rightEye = makeEye(iris: config.irisColor.uiColor)
        rightEye.name = rightEyeName
        rightEye.position = [rightEyeRestX * config.eyeSpacing, eyeRestY, eyeRestZ]
        rightEye.scale = SIMD3<Float>(repeating: config.eyeScale)
        root.addChild(rightEye)

        let leftLid = makeLid(skin: skin)
        leftLid.name = leftLidName
        leftLid.position = [leftEyeRestX * config.eyeSpacing, 0.048, 0.112]
        leftLid.scale = [1.05, 0.08, 1]
        root.addChild(leftLid)

        let rightLid = makeLid(skin: skin)
        rightLid.name = rightLidName
        rightLid.position = [rightEyeRestX * config.eyeSpacing, 0.048, 0.112]
        rightLid.scale = [1.05, 0.08, 1]
        root.addChild(rightLid)

        let leftBrow = makeBrow(hairColor: hairColor)
        leftBrow.name = leftBrowName
        leftBrow.position = [leftEyeRestX * config.eyeSpacing, 0.062, 0.112]
        leftBrow.scale = [config.browScale, 1, 1]
        root.addChild(leftBrow)

        let rightBrow = makeBrow(hairColor: hairColor)
        rightBrow.name = rightBrowName
        rightBrow.position = [rightEyeRestX * config.eyeSpacing, 0.062, 0.112]
        rightBrow.scale = [config.browScale, 1, 1]
        root.addChild(rightBrow)

        let nose = ModelEntity(
            mesh: .generateSphere(radius: 0.016),
            materials: [skinMaterial(skin.darker(by: 0.06), roughness: 0.45)]
        )
        nose.name = noseName
        nose.position = [0, -0.002, 0.128]
        nose.scale = [0.75 * config.noseScale, 0.95 * config.noseScale, 0.85 * config.noseScale]
        root.addChild(nose)

        let mouth = ModelEntity(
            mesh: .generateBox(size: [0.055, 0.016, 0.012], cornerRadius: 0.008),
            materials: [SimpleMaterial(color: UIColor(red: 0.86, green: 0.32, blue: 0.38, alpha: 1), roughness: .float(0.35), isMetallic: false)]
        )
        mouth.name = mouthName
        mouth.position = [0, -0.048, 0.118]
        mouth.scale = [config.mouthWidth, 1, 1]
        root.addChild(mouth)

        return root
    }

    private static func mix(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * t
    }

    private static func makeEar(name: String, x: Float, skin: UIColor) -> ModelEntity {
        let ear = ModelEntity(
            mesh: .generateSphere(radius: 0.022),
            materials: [skinMaterial(skin, roughness: 0.5)]
        )
        ear.name = name
        ear.position = [x, 0.0, 0.0]
        ear.scale = [0.55, 1.05, 0.7]
        return ear
    }

    private static func makeEye(iris: UIColor) -> ModelEntity {
        let eye = ModelEntity(
            mesh: .generateSphere(radius: 0.019),
            materials: [SimpleMaterial(color: .white, roughness: .float(0.25), isMetallic: false)]
        )

        let irisEntity = ModelEntity(
            mesh: .generateSphere(radius: 0.011),
            materials: [SimpleMaterial(color: iris, roughness: .float(0.3), isMetallic: false)]
        )
        irisEntity.name = "iris"
        irisEntity.position = [0, 0, 0.012]
        eye.addChild(irisEntity)

        let pupil = ModelEntity(
            mesh: .generateSphere(radius: 0.0055),
            materials: [SimpleMaterial(color: .black, roughness: .float(0.2), isMetallic: false)]
        )
        pupil.name = "pupil"
        pupil.position = [0, 0, 0.018]
        eye.addChild(pupil)

        let highlight = ModelEntity(
            mesh: .generateSphere(radius: 0.003),
            materials: [SimpleMaterial(color: .white, roughness: .float(0.1), isMetallic: false)]
        )
        highlight.position = [0.004, 0.004, 0.02]
        eye.addChild(highlight)

        return eye
    }

    private static func makeLid(skin: UIColor) -> ModelEntity {
        ModelEntity(
            mesh: .generateSphere(radius: 0.02),
            materials: [skinMaterial(skin, roughness: 0.45)]
        )
    }

    private static func makeBrow(hairColor: UIColor) -> ModelEntity {
        ModelEntity(
            mesh: .generateBox(size: [0.038, 0.007, 0.008], cornerRadius: 0.0035),
            materials: [SimpleMaterial(color: hairColor, roughness: .float(0.65), isMetallic: false)]
        )
    }

    private static func skinMaterial(_ color: UIColor, roughness: Float) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: .float(roughness), isMetallic: false)
    }
}
