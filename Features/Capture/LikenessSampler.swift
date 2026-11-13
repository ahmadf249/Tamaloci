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
        sample(cgImage: cgImage, contentBounds: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    /// Sample relative to an opaque content rect (normalized). Used for Memoji stickers with transparency.
    static func sample(cgImage: CGImage, contentBounds: CGRect) -> AppearanceSample {
        let b = contentBounds.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard b.width > 0.05, b.height > 0.05 else {
            return AppearanceSample(skin: nil, hair: nil, iris: nil, hairCoverage: 0.85)
        }

        func map(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
            CGPoint(x: b.minX + nx * b.width, y: b.minY + ny * b.height)
        }

        // Assumes a roughly centered face inside the content bounds.
        let skin = averageColor(cgImage, points: [
            map(0.42, 0.52),
            map(0.58, 0.52),
            map(0.50, 0.58),
            map(0.50, 0.48)
        ], requireOpaque: true)
        let hair = averageColor(cgImage, points: [
            map(0.50, 0.12),
            map(0.35, 0.18),
            map(0.65, 0.18),
            map(0.50, 0.08),
            map(0.42, 0.22),
            map(0.58, 0.22)
        ], requireOpaque: true)
        let iris = averageColor(cgImage, points: [
            map(0.38, 0.40),
            map(0.62, 0.40),
            map(0.38, 0.44),
            map(0.62, 0.44)
        ], requireOpaque: true)
        let coverage = estimateHairCoverage(hair: hair, skin: skin)
        return AppearanceSample(skin: skin, hair: hair, iris: iris, hairCoverage: coverage)
    }

    /// Opaque pixel bounds in normalized image coordinates (top-left origin). Full frame if fully opaque.
    static func opaqueContentBounds(in image: CGImage) -> CGRect {
        let width = image.width
        let height = image.height
        guard width > 1, height > 1,
              let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
        let length = CFDataGetLength(data)
        guard bytesPerPixel >= 4 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        var minX = width, minY = height, maxX = 0, maxY = 0
        var found = false
        // Stride for speed on large stickers.
        let step = max(1, min(width, height) / 64)
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let index = y * image.bytesPerRow + x * bytesPerPixel
                guard index + 3 < length else { continue }
                let alpha = ptr[index + 3]
                if alpha > 32 {
                    found = true
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        guard found, maxX > minX, maxY > minY else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        // Pad slightly so samples stay inside the silhouette.
        let padX = CGFloat(maxX - minX) * 0.04
        let padY = CGFloat(maxY - minY) * 0.04
        let left = max(0, (CGFloat(minX) - padX) / CGFloat(width))
        let top = max(0, (CGFloat(minY) - padY) / CGFloat(height))
        let right = min(1, (CGFloat(maxX) + padX) / CGFloat(width))
        let bottom = min(1, (CGFloat(maxY) + padY) / CGFloat(height))
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
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

    private static func averageColor(
        _ image: CGImage,
        points: [CGPoint],
        requireOpaque: Bool = false
    ) -> AvatarColor? {
        var rSum = 0.0, gSum = 0.0, bSum = 0.0
        var count = 0
        for point in points {
            if let c = color(at: point, in: image, requireOpaque: requireOpaque) {
                rSum += c.red; gSum += c.green; bSum += c.blue
                count += 1
            }
        }
        guard count > 0 else { return nil }
        let n = Double(count)
        return AvatarColor(red: rSum / n, green: gSum / n, blue: bSum / n)
    }

    private static func color(
        at normalized: CGPoint,
        in image: CGImage,
        requireOpaque: Bool = false
    ) -> AvatarColor? {
        let width = image.width
        let height = image.height
        guard width > 1, height > 1 else { return nil }
        let x = min(max(Int(normalized.x * CGFloat(width)), 0), width - 1)
        let y = min(max(Int(normalized.y * CGFloat(height)), 0), height - 1)

        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
        let index = y * image.bytesPerRow + x * bytesPerPixel
        let length = CFDataGetLength(data)
        guard index + 2 < length else { return nil }

        if requireOpaque, bytesPerPixel >= 4, index + 3 < length {
            let alpha = ptr[index + 3]
            if alpha < 64 { return nil }
        }

        let byte0 = Double(ptr[index]) / 255
        let byte1 = Double(ptr[index + 1]) / 255
        let byte2 = Double(ptr[index + 2]) / 255
        // Camera buffers are often BGRA; UIGraphics stickers are typically RGBA.
        let alphaFirst: Bool = {
            switch image.alphaInfo {
            case .premultipliedFirst, .first, .noneSkipFirst: return true
            default: return false
            }
        }()
        if image.bitmapInfo.contains(.byteOrder32Little) || alphaFirst {
            return AvatarColor(red: byte2, green: byte1, blue: byte0)
        }
        return AvatarColor(red: byte0, green: byte1, blue: byte2)
    }
}
