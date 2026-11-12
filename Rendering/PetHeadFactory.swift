import Foundation
import RealityKit

/// Single entry point for the pet head. Prefers a licensed USDZ in `Resources/3D`
/// when present and hierarchy-compatible; otherwise builds the procedural head.
enum PetHeadFactory {
    /// Bundle resource name (without extension) for an authored head, if licensed.
    static let usdzResourceName = "TamalociHead"

    static func makeHead(configuration: AvatarConfiguration = .default) -> Entity {
        if let authored = loadAuthoredHead() {
            applyConfiguration(configuration, to: authored)
            return authored
        }
        return ProceduralHeadBuilder.makeHead(configuration: configuration)
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
        if let skull = head.findEntity(named: ProceduralHeadBuilder.skullName) as? ModelEntity {
            skull.model?.materials = [
                SimpleMaterial(
                    color: configuration.skinTint.uiColor,
                    roughness: 0.55,
                    isMetallic: false
                )
            ]
        }
        let eyeScale = SIMD3<Float>(repeating: configuration.eyeScale)
        head.findEntity(named: ProceduralHeadBuilder.leftEyeName)?.scale = eyeScale
        head.findEntity(named: ProceduralHeadBuilder.rightEyeName)?.scale = eyeScale

        let browScale = SIMD3<Float>(configuration.browScale, 1, 1)
        head.findEntity(named: ProceduralHeadBuilder.leftBrowName)?.scale = browScale
        head.findEntity(named: ProceduralHeadBuilder.rightBrowName)?.scale = browScale
    }
}
