import SwiftUI

enum CareFXVisual: Equatable {
    case asset(String)
    case system(String)
}

/// Fly-in (or crossfade) care icon toward the pet head.
struct CareFXBurstView: View {
    let visual: CareFXVisual
    let reduceMotion: Bool
    var onFinished: () -> Void

    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        GeometryReader { geo in
            let start = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.82)
            let end = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.38)
            let t = progress
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            let scale = reduceMotion ? 0.9 : (1.2 - 0.6 * t)

            icon
                .frame(width: 88, height: 88)
                .scaleEffect(scale)
                .opacity(opacity)
                .position(reduceMotion ? end : CGPoint(x: x, y: y))
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
        .onAppear { runAnimation() }
    }

    @ViewBuilder
    private var icon: some View {
        switch visual {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
        case .system(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.accentColor)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private func runAnimation() {
        if reduceMotion {
            opacity = 1
            progress = 1
            withAnimation(.easeOut(duration: 0.35)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onFinished()
            }
            return
        }

        progress = 0
        opacity = 1
        withAnimation(.easeInOut(duration: 0.45)) {
            progress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            onFinished()
        }
    }
}
