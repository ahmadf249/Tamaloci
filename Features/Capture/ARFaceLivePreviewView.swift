import ARKit
import RealityKit
import SwiftUI

/// Live onboarding preview: ARKit face session drives stylized head likeness params
/// (colors + proportions). Never uses raw face mesh as the pet.
struct ARFaceLivePreviewView: UIViewRepresentable {
    @Binding var latestEstimate: AvatarParameterMapper.FaceEstimate
    var onSessionFailed: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(latestEstimate: $latestEstimate, onSessionFailed: onSessionFailed)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.session.delegate = context.coordinator

        let anchor = AnchorEntity(.face)
        let head = PetHeadFactory.makeHead(configuration: .default)
        head.scale = SIMD3<Float>(repeating: 0.42)
        head.position = [0, -0.025, 0.05]
        anchor.addChild(head)
        arView.scene.anchors.append(anchor)
        context.coordinator.headEntity = head

        if ARFaceTrackingConfiguration.isSupported {
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = true
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        } else {
            onSessionFailed?("Face tracking unsupported")
        }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        uiView.session.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        var latestEstimate: Binding<AvatarParameterMapper.FaceEstimate>
        var onSessionFailed: ((String) -> Void)?
        weak var headEntity: Entity?
        private var frameCount = 0
        private var runningEstimate: AvatarParameterMapper.FaceEstimate = .average
        private var latestPixelBuffer: CVPixelBuffer?

        init(
            latestEstimate: Binding<AvatarParameterMapper.FaceEstimate>,
            onSessionFailed: ((String) -> Void)?
        ) {
            self.latestEstimate = latestEstimate
            self.onSessionFailed = onSessionFailed
        }

        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor in
                onSessionFailed?(error.localizedDescription)
            }
        }

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let buffer = frame.capturedImage
            Task { @MainActor in
                self.latestPixelBuffer = buffer
            }
        }

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            Task { @MainActor in
                guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else { return }
                frameCount += 1
                guard frameCount % 2 == 0 else { return }

                var estimate = Self.geometryEstimate(from: face)
                if frameCount % 6 == 0, let buffer = latestPixelBuffer,
                   let appearance = LikenessSampler.sample(pixelBuffer: buffer) {
                    estimate.skinTint = appearance.skin
                    estimate.hairColor = appearance.hair
                    estimate.irisColor = appearance.iris
                    estimate.hairCoverage = appearance.hairCoverage
                } else {
                    estimate.skinTint = runningEstimate.skinTint
                    estimate.hairColor = runningEstimate.hairColor
                    estimate.irisColor = runningEstimate.irisColor
                    estimate.hairCoverage = runningEstimate.hairCoverage
                }

                runningEstimate = AvatarParameterMapper.blend(runningEstimate, with: estimate, amount: 0.4)
                latestEstimate.wrappedValue = runningEstimate
                if let head = headEntity {
                    let config = AvatarParameterMapper.makeConfiguration(from: runningEstimate)
                    PetHeadFactory.applyConfiguration(config, to: head)
                }
            }
        }

        private static func geometryEstimate(from anchor: ARFaceAnchor) -> AvatarParameterMapper.FaceEstimate {
            let vertices = anchor.geometry.vertices
            var minX: Float = 0
            var maxX: Float = 0
            var minY: Float = 0
            var maxY: Float = 0
            var minZ: Float = 0
            var maxZ: Float = 0
            if let first = vertices.first {
                minX = first.x; maxX = first.x
                minY = first.y; maxY = first.y
                minZ = first.z; maxZ = first.z
            }
            for v in vertices {
                minX = min(minX, v.x); maxX = max(maxX, v.x)
                minY = min(minY, v.y); maxY = max(maxY, v.y)
                minZ = min(minZ, v.z); maxZ = max(maxZ, v.z)
            }
            let width = max(maxX - minX, 0.001)
            let height = max(maxY - minY, 0.001)
            let depth = max(maxZ - minZ, 0.001)

            // Jaw cue: lower third width vs overall — approximate with depth/width ratio.
            let jawWidth = ((width * 0.92) / 0.13).clamped(to: 0.85...1.25)
            let brow = (anchor.blendShapes[.browDownLeft]?.floatValue ?? 0)
                + (anchor.blendShapes[.browDownRight]?.floatValue ?? 0)
            let mouthWide = anchor.blendShapes[.mouthStretchLeft]?.floatValue ?? 0
            let eyeBlink = ((anchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0)
                + (anchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0)) * 0.5

            return AvatarParameterMapper.FaceEstimate(
                faceWidth: (width / 0.14).clamped(to: 0.85...1.2),
                jawWidth: jawWidth,
                eyeSpacing: ((width * 0.32) / 0.048).clamped(to: 0.8...1.25),
                eyeSize: (1.05 - eyeBlink * 0.2).clamped(to: 0.75...1.35),
                browScale: (1.0 + brow * 0.25).clamped(to: 0.7...1.4),
                noseScale: ((depth * 0.55) / 0.045).clamped(to: 0.75...1.35),
                mouthWidth: (1.0 + mouthWide * 0.35).clamped(to: 0.75...1.4),
                faceLength: (height / 0.16).clamped(to: 0.9...1.15),
                hairCoverage: 0.85,
                skinTint: nil,
                hairColor: nil,
                irisColor: nil
            )
        }
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
