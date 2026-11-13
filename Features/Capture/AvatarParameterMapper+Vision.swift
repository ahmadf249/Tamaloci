import CoreGraphics
import Foundation
import UIKit
import Vision

extension AvatarParameterMapper {
    /// Estimate stylized params from a still selfie using Vision landmarks + color sampling.
    static func estimate(fromSelfie image: UIImage) -> FaceEstimate {
        guard let cgImage = image.tamaloci_rasterizedCGImage() else { return .average }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return appearanceOnlyEstimate(from: cgImage, preferStickerBounds: false)
        }

        guard let face = request.results?.first else {
            // No photographic face (common for stickers / failed selfie) — still sample colors.
            return appearanceOnlyEstimate(from: cgImage, preferStickerBounds: false)
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

    /// Memoji / Genmoji stickers rarely pass Vision face detection. Rasterize, crop to opaque
    /// silhouette, sample colors, and derive light morphs from the sticker aspect ratio.
    static func estimate(fromSticker image: UIImage) -> FaceEstimate {
        guard let cgImage = image.tamaloci_rasterizedCGImage() else { return .average }

        let bounds = LikenessSampler.opaqueContentBounds(in: cgImage)
        let appearance = LikenessSampler.sample(cgImage: cgImage, contentBounds: bounds)
        let silhouette = appearanceOnlyEstimate(from: cgImage, preferStickerBounds: true)

        // If Vision detects a face, borrow geometry; always prefer sticker color samples.
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        if (try? handler.perform([request])) != nil, request.results?.first != nil {
            let selfie = estimate(fromSelfie: image)
            return FaceEstimate(
                faceWidth: selfie.faceWidth,
                jawWidth: selfie.jawWidth,
                eyeSpacing: selfie.eyeSpacing,
                eyeSize: selfie.eyeSize,
                browScale: selfie.browScale,
                noseScale: selfie.noseScale,
                mouthWidth: selfie.mouthWidth,
                faceLength: selfie.faceLength,
                hairCoverage: appearance.hairCoverage,
                skinTint: appearance.skin ?? selfie.skinTint,
                hairColor: appearance.hair ?? selfie.hairColor,
                irisColor: appearance.iris ?? selfie.irisColor
            )
        }

        return FaceEstimate(
            faceWidth: silhouette.faceWidth,
            jawWidth: silhouette.jawWidth,
            eyeSpacing: silhouette.eyeSpacing,
            eyeSize: silhouette.eyeSize,
            browScale: silhouette.browScale,
            noseScale: silhouette.noseScale,
            mouthWidth: silhouette.mouthWidth,
            faceLength: silhouette.faceLength,
            hairCoverage: appearance.hairCoverage,
            skinTint: appearance.skin,
            hairColor: appearance.hair,
            irisColor: appearance.iris
        )
    }

    private static func appearanceOnlyEstimate(
        from cgImage: CGImage,
        preferStickerBounds: Bool
    ) -> FaceEstimate {
        let bounds = preferStickerBounds
            ? LikenessSampler.opaqueContentBounds(in: cgImage)
            : CGRect(x: 0, y: 0, width: 1, height: 1)
        let appearance = LikenessSampler.sample(cgImage: cgImage, contentBounds: bounds)

        let aspect = Float(bounds.width / max(bounds.height, 0.001))
        // Wider silhouette → slightly wider head; taller → longer face.
        let faceWidth = (0.95 + (aspect - 0.85) * 0.35).clamped(to: 0.85...1.2)
        let faceLength = (1.05 - (aspect - 0.85) * 0.25).clamped(to: 0.9...1.15)
        let jawWidth = faceWidth

        return FaceEstimate(
            faceWidth: faceWidth,
            jawWidth: jawWidth,
            eyeSpacing: 1,
            eyeSize: 1.05,
            browScale: 1,
            noseScale: 1,
            mouthWidth: 1.05,
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

extension UIImage {
    /// Ensures a bitmap `CGImage` even when `cgImage` is nil (common for HEIC / glyph payloads).
    func tamaloci_rasterizedCGImage() -> CGImage? {
        if let cgImage { return cgImage }
        let target = size
        guard target.width > 1, target.height > 1 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = max(scale, 1)
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.cgImage
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
