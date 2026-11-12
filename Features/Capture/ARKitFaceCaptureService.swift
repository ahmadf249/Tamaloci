import ARKit
import Foundation
import RealityKit
import UIKit

/// Short ARKit face session used only during onboarding. Stops after estimate.
@MainActor
final class ARKitFaceCaptureService: NSObject {
    private var session: ARSession?
    private var continuation: CheckedContinuation<AvatarParameterMapper.FaceEstimate, Error>?
    private var samples: [AvatarParameterMapper.FaceEstimate] = []
    private let maxSamples = 18
    private var isRunning = false

    static var isSupported: Bool { FaceCaptureCapability.isARFaceTrackingSupported }

    func captureEstimate(timeoutSeconds: TimeInterval = 4) async throws -> AvatarParameterMapper.FaceEstimate {
        guard Self.isSupported else {
            throw CaptureError.arkitUnsupported
        }
        guard !isRunning else {
            throw CaptureError.busy
        }

        isRunning = true
        samples.removeAll()
        let session = ARSession()
        self.session = session
        session.delegate = self

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        session.run(config, options: [.resetTracking, .removeExistingAnchors])

        defer { tearDown() }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                await self?.finishIfNeeded()
            }
        }
    }

    func tearDown() {
        session?.pause()
        session?.delegate = nil
        session = nil
        isRunning = false
    }

    private func finishIfNeeded() {
        guard let continuation else { return }
        self.continuation = nil
        if samples.isEmpty {
            continuation.resume(returning: .average)
        } else {
            continuation.resume(returning: average(samples))
        }
    }

    private func average(_ values: [AvatarParameterMapper.FaceEstimate]) -> AvatarParameterMapper.FaceEstimate {
        let count = Float(values.count)
        func mean(_ keyPath: KeyPath<AvatarParameterMapper.FaceEstimate, Float>) -> Float {
            values.map { $0[keyPath: keyPath] }.reduce(0, +) / count
        }
        return AvatarParameterMapper.FaceEstimate(
            faceWidth: mean(\.faceWidth),
            jawWidth: mean(\.jawWidth),
            eyeSpacing: mean(\.eyeSpacing),
            eyeSize: mean(\.eyeSize),
            browScale: mean(\.browScale),
            noseScale: mean(\.noseScale),
            mouthWidth: mean(\.mouthWidth),
            faceLength: mean(\.faceLength),
            hairCoverage: mean(\.hairCoverage),
            skinTint: values.last?.skinTint,
            hairColor: values.last?.hairColor,
            irisColor: values.last?.irisColor
        )
    }

    private func estimate(from anchor: ARFaceAnchor) -> AvatarParameterMapper.FaceEstimate {
        // Use geometry extents only as relative cues — never as the pet mesh.
        let vertices = anchor.geometry.vertices
        var minX: Float = 0
        var maxX: Float = 0
        var minY: Float = 0
        var maxY: Float = 0
        if let first = vertices.first {
            minX = first.x; maxX = first.x
            minY = first.y; maxY = first.y
        }
        for v in vertices {
            minX = min(minX, v.x); maxX = max(maxX, v.x)
            minY = min(minY, v.y); maxY = max(maxY, v.y)
        }
        let width = max(maxX - minX, 0.001)
        let height = max(maxY - minY, 0.001)
        let faceWidth = (width / 0.14).clamped(to: 0.85...1.2)
        let jawWidth = faceWidth
        let eyeSpacing = ((width * 0.35) / 0.05).clamped(to: 0.8...1.25)
        let eyeSize = ((height * 0.12) / 0.03).clamped(to: 0.75...1.35)
        let noseScale = ((height * 0.18) / 0.04).clamped(to: 0.75...1.35)
        let mouthWidth = ((width * 0.4) / 0.055).clamped(to: 0.75...1.4)

        return AvatarParameterMapper.FaceEstimate(
            faceWidth: faceWidth,
            jawWidth: jawWidth,
            eyeSpacing: eyeSpacing,
            eyeSize: eyeSize,
            browScale: 1,
            noseScale: noseScale,
            mouthWidth: mouthWidth,
            faceLength: (height / 0.16).clamped(to: 0.9...1.15),
            hairCoverage: 0.85,
            skinTint: nil,
            hairColor: nil,
            irisColor: nil
        )
    }
}

extension ARKitFaceCaptureService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            guard isRunning, continuation != nil else { return }
            for case let face as ARFaceAnchor in anchors where face.isTracked {
                samples.append(estimate(from: face))
                if samples.count >= maxSamples {
                    finishIfNeeded()
                }
                break
            }
        }
    }
}

enum CaptureError: LocalizedError {
    case arkitUnsupported
    case busy
    case cancelled
    case cameraDenied

    var errorDescription: String? {
        switch self {
        case .arkitUnsupported: return "Face tracking is not available on this device."
        case .busy: return "Capture is already running."
        case .cancelled: return "Capture was cancelled."
        case .cameraDenied: return "Camera access was denied."
        }
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
