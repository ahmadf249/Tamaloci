import CoreImage
import CoreVideo
import Foundation
import UIKit

/// Samples skin / hair / iris colors and hair coverage from camera or selfie pixels.
/// Used to drive stylized likeness (not photoreal reconstruction).
enum LikenessSampler {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    struct AppearanceSample: Equatable, Sendable {
        var skin: AvatarColor?
        var hair: AvatarColor?
        var iris: AvatarColor?
        /// 0…1 denser/darker crown → higher coverage.
        var hairCoverage: Float
    }

    /// Normalized image points use top-left origin, x/y in 0…1.
    static func sample(cgImage: CGImage) -> AppearanceSample {
        // Assumes a roughly centered face (onboarding capture).
        let skin = averageColor(cgImage, points: [
            CGPoint(x: 0.42, y: 0.52),
            CGPoint(x: 0.58, y: 0.52),
            CGPoint(x: 0.50, y: 0.58)
        ])
        let hair = averageColor(cgImage, points: [
            CGPoint(x: 0.50, y: 0.16),
            CGPoint(x: 0.38, y: 0.20),
            CGPoint(x: 0.62, y: 0.20),
            CGPoint(x: 0.50, y: 0.10)
        ])
        let iris = averageColor(cgImage, points: [
            CGPoint(x: 0.38, y: 0.42),
            CGPoint(x: 0.62, y: 0.42)
        ])
        let coverage = estimateHairCoverage(hair: hair, skin: skin)
        return AppearanceSample(skin: skin, hair: hair, iris: iris, hairCoverage: coverage)
    }

    static func sample(pixelBuffer: CVPixelBuffer) -> AppearanceSample? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Front camera buffers are often landscape-right; rotate to upright portrait.
        let upright = ciImage.oriented(.right)
        guard let cgImage = ciContext.createCGImage(upright, from: upright.extent) else {
            return nil
        }
        return sample(cgImage: cgImage)
    }

    private static func estimateHairCoverage(hair: AvatarColor?, skin: AvatarColor?) -> Float {
        guard let hair else { return 0.7 }
        let luminance = 0.2126 * hair.red + 0.7152 * hair.green + 0.0722 * hair.blue
        // Darker crown → more coverage. Very light (scalp/blonde wash) → still keep some hair.
        var coverage = Float(1.15 - luminance)
        if let skin {
            let skinLum = 0.2126 * skin.red + 0.7152 * skin.green + 0.0722 * skin.blue
            // If hair region is close to skin luminance, user may have thin/short hair or balding crown.
            let delta = abs(skinLum - luminance)
            if delta < 0.08 {
                coverage *= 0.45
            } else if delta < 0.15 {
                coverage *= 0.7
            }
        }
        return min(max(coverage, 0.2), 1)
    }

    private static func averageColor(_ image: CGImage, points: [CGPoint]) -> AvatarColor? {
        var rSum = 0.0, gSum = 0.0, bSum = 0.0
        var count = 0
        for point in points {
            if let c = color(at: point, in: image) {
                rSum += c.red; gSum += c.green; bSum += c.blue
                count += 1
            }
        }
        guard count > 0 else { return nil }
        let n = Double(count)
        return AvatarColor(red: rSum / n, green: gSum / n, blue: bSum / n)
    }

    private static func color(at normalized: CGPoint, in image: CGImage) -> AvatarColor? {
        let width = image.width
        let height = image.height
        guard width > 1, height > 1 else { return nil }
        let x = min(max(Int(normalized.x * CGFloat(width)), 0), width - 1)
        let y = min(max(Int(normalized.y * CGFloat(height)), 0), height - 1)

        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
        let index = y * image.bytesPerRow + x * bytesPerPixel
        guard index + 2 < CFDataGetLength(data) else { return nil }

        // Handle common BGRA camera buffers vs RGB.
        let byte0 = Double(ptr[index]) / 255
        let byte1 = Double(ptr[index + 1]) / 255
        let byte2 = Double(ptr[index + 2]) / 255
        if image.bitmapInfo.contains(.byteOrder32Little) || bytesPerPixel >= 4 {
            // BGRA
            return AvatarColor(red: byte2, green: byte1, blue: byte0)
        }
        return AvatarColor(red: byte0, green: byte1, blue: byte2)
    }
}
