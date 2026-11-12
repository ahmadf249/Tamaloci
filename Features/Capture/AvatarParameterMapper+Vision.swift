import CoreGraphics
import Foundation
import UIKit
import Vision

extension AvatarParameterMapper {
    /// Estimate stylized params from a still selfie using Vision landmarks + color sampling.
    static func estimate(fromSelfie image: UIImage) -> FaceEstimate {
        guard let cgImage = image.cgImage else { return .average }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .average
        }

        guard let face = request.results?.first else {
            return .average
        }

        let box = face.boundingBox
        let faceWidth = Float(box.width / 0.45).clamped(to: 0.85...1.2)
        let faceLength = Float(box.height / 0.55).clamped(to: 0.9...1.15)

        var eyeSpacing: Float = 1
        var eyeSize: Float = 1
        var mouthWidth: Float = 1
        var noseScale: Float = 1
        var jawWidth: Float = faceWidth
        var browScale: Float = 1

        if let landmarks = face.landmarks {
            if let left = landmarks.leftEye?.normalizedPoints,
               let right = landmarks.rightEye?.normalizedPoints,
               let leftCenter = centroid(left),
               let rightCenter = centroid(right) {
                let dist = hypot(leftCenter.x - rightCenter.x, leftCenter.y - rightCenter.y)
                eyeSpacing = Float(dist / 0.22).clamped(to: 0.8...1.25)
                let leftSpan = span(left)
                let rightSpan = span(right)
                eyeSize = Float(((leftSpan + rightSpan) * 0.5) / 0.08).clamped(to: 0.75...1.35)
            }
            if let mouth = landmarks.outerLips?.normalizedPoints {
                mouthWidth = Float(span(mouth) / 0.18).clamped(to: 0.75...1.4)
            }
            if let nose = landmarks.nose?.normalizedPoints {
                noseScale = Float(span(nose) / 0.1).clamped(to: 0.75...1.35)
            }
            if let contour = landmarks.faceContour?.normalizedPoints, contour.count >= 2 {
                let xs = contour.map(\.x)
                if let minX = xs.min(), let maxX = xs.max() {
                    jawWidth = Float((maxX - minX) / 0.55).clamped(to: 0.85...1.25)
                }
            }
            if let leftBrow = landmarks.leftEyebrow?.normalizedPoints,
               let rightBrow = landmarks.rightEyebrow?.normalizedPoints {
                let browSpan = (span(leftBrow) + span(rightBrow)) * 0.5
                browScale = Float(browSpan / 0.12).clamped(to: 0.7...1.4)
            }
        }

        let appearance = LikenessSampler.sample(cgImage: cgImage)

        return FaceEstimate(
            faceWidth: faceWidth,
            jawWidth: jawWidth,
            eyeSpacing: eyeSpacing,
            eyeSize: eyeSize,
            browScale: browScale,
            noseScale: noseScale,
            mouthWidth: mouthWidth,
            faceLength: faceLength,
            hairCoverage: appearance.hairCoverage,
            skinTint: appearance.skin,
            hairColor: appearance.hair,
            irisColor: appearance.iris
        )
    }

    private static func centroid(_ points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private static func span(_ points: [CGPoint]) -> CGFloat {
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max() else { return 0 }
        return maxX - minX
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
