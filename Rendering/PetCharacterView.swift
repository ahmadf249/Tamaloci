import RealityKit
import SwiftUI
import UIKit

struct PetCharacterView: UIViewRepresentable {
    @Binding var expression: PetExpression
    var avatarConfiguration: AvatarConfiguration = .default
    var reduceMotion: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.cameraMode = .nonAR
        arView.environment.background = .color(.clear)
        arView.renderOptions.insert(.disableMotionBlur)

        let anchor = AnchorEntity(world: .zero)
        let head = PetHeadFactory.makeHead(configuration: avatarConfiguration)
        head.position = [0, 0, 0]
        anchor.addChild(head)
        context.coordinator.appliedConfiguration = avatarConfiguration

        let light = DirectionalLight()
        light.light.color = .white
        light.light.intensity = 1200
        light.look(at: [0, 0, 0], from: [0.4, 0.8, 0.6], relativeTo: nil)
        anchor.addChild(light)

        let fill = PointLight()
        fill.light.color = UIColor(white: 1, alpha: 1)
        fill.light.intensity = 400
        fill.light.attenuationRadius = 4
        fill.position = [-0.3, 0.2, 0.5]
        anchor.addChild(fill)

        arView.scene.anchors.append(anchor)

        // Camera framing for a floating head.
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 40
        let cameraAnchor = AnchorEntity(world: [0, 0, 0.55])
        cameraAnchor.addChild(camera)
        arView.scene.anchors.append(cameraAnchor)

        context.coordinator.animationController.attach(
            to: head,
            reduceMotion: reduceMotion,
            configuration: avatarConfiguration
        )
        context.coordinator.headRoot = head
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        let controller = context.coordinator.animationController
        controller.updateReduceMotion(reduceMotion)
        if context.coordinator.appliedConfiguration != avatarConfiguration,
           let head = context.coordinator.headRoot {
            PetHeadFactory.applyConfiguration(avatarConfiguration, to: head)
            context.coordinator.appliedConfiguration = avatarConfiguration
            controller.applyAppearanceBaseline(avatarConfiguration)
            controller.setExpression(expression, animated: false)
        }
        if controller.currentExpression != expression {
            controller.setExpression(expression)
        }
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.animationController.tearDown()
    }

    @MainActor
    final class Coordinator {
        let animationController = PetAnimationController()
        var headRoot: Entity?
        var appliedConfiguration: AvatarConfiguration = .default
    }
}
