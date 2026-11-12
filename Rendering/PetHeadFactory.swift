import Foundation
import RealityKit
import UIKit

/// Single entry point for the pet head. Prefers a licensed USDZ in `Resources/3D`
/// when present and hierarchy-compatible; otherwise builds the procedural head.
enum PetHeadFactory {
    /// Bundle resource name (without extension) for an authored head, if licensed.
    static let usdzResourceName = "TamalociHead"

    static func makeHead(configuration: AvatarConfiguration = .default) -> Entity {
        let config = configuration.clamped()
        if let authored = loadAuthoredHead() {
            applyConfiguration(config, to: authored)
            return authored
        }
        return ProceduralHeadBuilder.makeHead(configuration: config)
    }

    // MARK: - USDZ

    private static func loadAuthoredHead() -> Entity? {
        guard let url = Bundle.main.url(forResource: usdzResourceName, withExtension: "usdz") else {
            return nil
        }
        guard let loaded = try? Entity.load(contentsOf: url) else {
            return nil
        }
        let root: Entity
        if loaded.name == ProceduralHeadBuilder.headName {
            root = loaded
        } else if let named = loaded.findEntity(named: ProceduralHeadBuilder.headName) {
            root = named
            root.removeFromParent()
        } else {
            loaded.name = ProceduralHeadBuilder.headName
            root = loaded
        }
        guard hasRequiredFaceParts(root) else {
            return nil
        }
        return root
    }

    private static func hasRequiredFaceParts(_ root: Entity) -> Bool {
        let required = [
            ProceduralHeadBuilder.skullName,
            ProceduralHeadBuilder.leftEyeName,
            ProceduralHeadBuilder.rightEyeName,
            ProceduralHeadBuilder.leftLidName,
            ProceduralHeadBuilder.rightLidName,
            ProceduralHeadBuilder.leftBrowName,
            ProceduralHeadBuilder.rightBrowName,
            ProceduralHeadBuilder.mouthName
        ]
        return required.allSatisfy { root.findEntity(named: $0) != nil }
    }

    // MARK: - Configuration

    static func applyConfiguration(_ configuration: AvatarConfiguration, to head: Entity) {
        let config = configuration.clamped()
        let skin = config.skinTint.uiColor
        let hair = config.hairColor.uiColor
        let iris = config.irisColor.uiColor

        if let skull = head.findEntity(named: ProceduralHeadBuilder.skullName) as? ModelEntity {
            skull.model?.materials = [SimpleMaterial(color: skin, roughness: .float(0.42), isMetallic: false)]
            skull.scale = [
                config.headWidth * 0.95,
                1.02 * config.faceLength,
                0.92 + (config.jawWidth - 1) * 0.4
            ]
        }

        if let crown = head.findEntity(named: ProceduralHeadBuilder.hairCrownName) as? ModelEntity {
            crown.model?.materials = [SimpleMaterial(color: hair, roughness: .float(0.68), isMetallic: false)]
            let crownCover = 0.55 + config.hairCoverage * 0.45
            crown.scale = [
                config.headWidth * (0.92 + config.hairCoverage * 0.08),
                crownCover * 0.75,
                0.9 + config.hairCoverage * 0.08
            ]
            crown.position.y = 0.055 * config.faceLength
            crown.isEnabled = config.hairCoverage > 0.2
        }

        if let hairEntity = head.findEntity(named: ProceduralHeadBuilder.hairName) as? ModelEntity {
            hairEntity.model?.materials = [SimpleMaterial(color: hair, roughness: .float(0.72), isMetallic: false)]
            hairEntity.scale = [
                config.headWidth * (0.98 + config.hairCoverage * 0.04),
                0.55 + config.hairCoverage * 0.35,
                0.95
            ]
            hairEntity.isEnabled = config.hairCoverage > 0.15
        }

        for earName in ["leftEar", "rightEar"] {
            if let ear = head.findEntity(named: earName) as? ModelEntity {
                ear.model?.materials = [SimpleMaterial(color: skin, roughness: .float(0.5), isMetallic: false)]
            }
        }

        let cheekTint = skin.blended(toward: UIColor(red: 1, green: 0.55, blue: 0.55, alpha: 1), amount: 0.18)
        for cheekName in [ProceduralHeadBuilder.leftCheekName, ProceduralHeadBuilder.rightCheekName] {
            if let cheek = head.findEntity(named: cheekName) as? ModelEntity {
                cheek.model?.materials = [SimpleMaterial(color: cheekTint, roughness: .float(0.5), isMetallic: false)]
            }
        }
        head.findEntity(named: ProceduralHeadBuilder.leftCheekName)?.position.x = -0.055 * config.headWidth
        head.findEntity(named: ProceduralHeadBuilder.rightCheekName)?.position.x = 0.055 * config.headWidth

        let leftX = ProceduralHeadBuilder.leftEyeRestX * config.eyeSpacing
        let rightX = ProceduralHeadBuilder.rightEyeRestX * config.eyeSpacing
        let eyeScale = SIMD3<Float>(repeating: config.eyeScale)

        if let leftEye = head.findEntity(named: ProceduralHeadBuilder.leftEyeName) {
            leftEye.position = [leftX, ProceduralHeadBuilder.eyeRestY, ProceduralHeadBuilder.eyeRestZ]
            leftEye.scale = eyeScale
            if let irisEntity = leftEye.findEntity(named: "iris") as? ModelEntity {
                irisEntity.model?.materials = [SimpleMaterial(color: iris, roughness: .float(0.3), isMetallic: false)]
            }
        }
        if let rightEye = head.findEntity(named: ProceduralHeadBuilder.rightEyeName) {
            rightEye.position = [rightX, ProceduralHeadBuilder.eyeRestY, ProceduralHeadBuilder.eyeRestZ]
            rightEye.scale = eyeScale
            if let irisEntity = rightEye.findEntity(named: "iris") as? ModelEntity {
                irisEntity.model?.materials = [SimpleMaterial(color: iris, roughness: .float(0.3), isMetallic: false)]
            }
        }

        for lidName in [ProceduralHeadBuilder.leftLidName, ProceduralHeadBuilder.rightLidName] {
            if let lid = head.findEntity(named: lidName) as? ModelEntity {
                lid.model?.materials = [SimpleMaterial(color: skin, roughness: .float(0.45), isMetallic: false)]
            }
        }
        head.findEntity(named: ProceduralHeadBuilder.leftLidName)?.position = [leftX, 0.048, 0.112]
        head.findEntity(named: ProceduralHeadBuilder.rightLidName)?.position = [rightX, 0.048, 0.112]

        let browScale = SIMD3<Float>(config.browScale, 1, 1)
        if let leftBrow = head.findEntity(named: ProceduralHeadBuilder.leftBrowName) as? ModelEntity {
            leftBrow.position = [leftX, 0.062, 0.112]
            leftBrow.scale = browScale
            leftBrow.model?.materials = [SimpleMaterial(color: hair, roughness: .float(0.65), isMetallic: false)]
        }
        if let rightBrow = head.findEntity(named: ProceduralHeadBuilder.rightBrowName) as? ModelEntity {
            rightBrow.position = [rightX, 0.062, 0.112]
            rightBrow.scale = browScale
            rightBrow.model?.materials = [SimpleMaterial(color: hair, roughness: .float(0.65), isMetallic: false)]
        }

        if let nose = head.findEntity(named: ProceduralHeadBuilder.noseName) as? ModelEntity {
            nose.model?.materials = [SimpleMaterial(color: skin.darker(by: 0.06), roughness: .float(0.45), isMetallic: false)]
            nose.scale = [0.75 * config.noseScale, 0.95 * config.noseScale, 0.85 * config.noseScale]
        }
        if let mouth = head.findEntity(named: ProceduralHeadBuilder.mouthName) {
            var scale = mouth.scale
            scale.x = config.mouthWidth
            mouth.scale = scale
        }
    }
}
