import SwiftUI

/// Lightweight likeness chip for memorial rows (no RealityKit).
struct AvatarThumbnailView: View {
    let configuration: AvatarConfiguration

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(uiColor: configuration.skinTint.uiColor))
            Circle()
                .trim(from: 0.55, to: 1.0)
                .fill(Color(uiColor: configuration.hairColor.uiColor).opacity(0.35 + Double(configuration.hairCoverage) * 0.55))
                .rotationEffect(.degrees(180))
                .scaleEffect(x: 1.05, y: 0.85)
                .offset(y: -6)
            HStack(spacing: 10 * CGFloat(configuration.eyeSpacing)) {
                eye
                eye
            }
            .offset(y: -2)
            Capsule()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 14 * CGFloat(configuration.mouthWidth), height: 3)
                .offset(y: 12)
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 8 * CGFloat(configuration.eyeScale), height: 8 * CGFloat(configuration.eyeScale))
            .overlay(
                Circle()
                    .fill(Color(uiColor: configuration.irisColor.uiColor))
                    .frame(width: 4 * CGFloat(configuration.eyeScale), height: 4 * CGFloat(configuration.eyeScale))
            )
    }
}
