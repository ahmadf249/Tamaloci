import RealityKit
import UIKit

/// Builds a stylized Memoji-inspired floating head from primitives.
/// Later replaced by an authored USDZ with blend shapes (PDF §3.6) without changing the expression API.
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

    static func makeHead() -> Entity {
        let root = Entity()
        root.name = headName

        let skull = ModelEntity(
            mesh: .generateSphere(radius: 0.12),
            materials: [skinMaterial(UIColor(red: 0.96, green: 0.80, blue: 0.70, alpha: 1))]
        )
        skull.name = skullName
        root.addChild(skull)

        let leftEye = makeEye()
        leftEye.name = leftEyeName
        leftEye.position = [-0.04, 0.025, 0.10]
        root.addChild(leftEye)

        let rightEye = makeEye()
        rightEye.name = rightEyeName
        rightEye.position = [0.04, 0.025, 0.10]
        root.addChild(rightEye)

        let leftLid = makeLid()
        leftLid.name = leftLidName
        leftLid.position = [-0.04, 0.045, 0.105]
        leftLid.scale = [1, 0.05, 1]
        root.addChild(leftLid)

        let rightLid = makeLid()
        rightLid.name = rightLidName
        rightLid.position = [0.04, 0.045, 0.105]
        rightLid.scale = [1, 0.05, 1]
        root.addChild(rightLid)

        let leftBrow = makeBrow()
        leftBrow.name = leftBrowName
        leftBrow.position = [-0.04, 0.06, 0.105]
        root.addChild(leftBrow)

        let rightBrow = makeBrow()
        rightBrow.name = rightBrowName
        rightBrow.position = [0.04, 0.06, 0.105]
        root.addChild(rightBrow)

        let nose = ModelEntity(
            mesh: .generateSphere(radius: 0.018),
            materials: [skinMaterial(UIColor(red: 0.92, green: 0.72, blue: 0.62, alpha: 1))]
        )
        nose.name = noseName
        nose.position = [0, -0.005, 0.118]
        nose.scale = [0.7, 1.0, 0.7]
        root.addChild(nose)

        let mouth = ModelEntity(
            mesh: .generateBox(size: [0.05, 0.012, 0.01], cornerRadius: 0.006),
            materials: [SimpleMaterial(color: UIColor(red: 0.75, green: 0.25, blue: 0.30, alpha: 1), isMetallic: false)]
        )
        mouth.name = mouthName
        mouth.position = [0, -0.045, 0.11]
        root.addChild(mouth)

        return root
    }

    private static func makeEye() -> ModelEntity {
        ModelEntity(
            mesh: .generateSphere(radius: 0.018),
            materials: [SimpleMaterial(color: .white, isMetallic: false)]
        )
    }

    private static func makeLid() -> ModelEntity {
        ModelEntity(
            mesh: .generateSphere(radius: 0.019),
            materials: [skinMaterial(UIColor(red: 0.96, green: 0.80, blue: 0.70, alpha: 1))]
        )
    }

    private static func makeBrow() -> ModelEntity {
        ModelEntity(
            mesh: .generateBox(size: [0.035, 0.006, 0.008], cornerRadius: 0.003),
            materials: [SimpleMaterial(color: UIColor(red: 0.25, green: 0.15, blue: 0.10, alpha: 1), isMetallic: false)]
        )
    }

    private static func skinMaterial(_ color: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: 0.55, isMetallic: false)
    }
}
