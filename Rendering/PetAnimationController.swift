import Foundation
import RealityKit
import UIKit

/// Drives facial expressions and idle motion on the pet head. Kept free of SwiftUI
/// so the future pet simulation can call `setExpression(_:)` directly (PDF §3.5, §7.1).
@MainActor
final class PetAnimationController {
    private(set) var currentExpression: PetExpression = .neutral
    private weak var headRoot: Entity?
    private var blinkTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var reduceMotion: Bool = false
    private var isBlinking = false

    private let neutralMouthPosition = SIMD3<Float>(0, -0.048, 0.118)
    private let neutralBrowY: Float = 0.062
    private var leftEyeRest = SIMD3<Float>(-0.04, 0.025, 0.10)
    private var rightEyeRest = SIMD3<Float>(0.04, 0.025, 0.10)
    private var baseEyeScale = SIMD3<Float>(1, 1, 1)
    private var baseMouthWidth: Float = 1
    private var baseSkin = UIColor(red: 0.96, green: 0.80, blue: 0.70, alpha: 1)

    func attach(to headRoot: Entity, reduceMotion: Bool, configuration: AvatarConfiguration = .default) {
        self.headRoot = headRoot
        self.reduceMotion = reduceMotion
        applyAppearanceBaseline(configuration)
        setExpression(.neutral, animated: false)
        startBlinkLoop()
        startIdleMotion()
    }

    /// Call after `PetHeadFactory.applyConfiguration` so expression poses keep appearance.
    func applyAppearanceBaseline(_ configuration: AvatarConfiguration) {
        let config = configuration.clamped()
        baseEyeScale = SIMD3<Float>(repeating: config.eyeScale)
        baseMouthWidth = config.mouthWidth
        baseSkin = config.skinTint.uiColor
        leftEyeRest = [
            ProceduralHeadBuilder.leftEyeRestX * config.eyeSpacing,
            ProceduralHeadBuilder.eyeRestY,
            ProceduralHeadBuilder.eyeRestZ
        ]
        rightEyeRest = [
            ProceduralHeadBuilder.rightEyeRestX * config.eyeSpacing,
            ProceduralHeadBuilder.eyeRestY,
            ProceduralHeadBuilder.eyeRestZ
        ]
    }

    func updateReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        if enabled {
            idleTask?.cancel()
            idleTask = nil
            resetIdlePose()
        } else if idleTask == nil {
            startIdleMotion()
        }
    }

    func setExpression(_ expression: PetExpression, animated: Bool = true) {
        guard let head = headRoot else { return }
        currentExpression = expression
        apply(expression, to: head, animated: animated)
    }

    func tearDown() {
        blinkTask?.cancel()
        idleTask?.cancel()
        blinkTask = nil
        idleTask = nil
        headRoot = nil
    }

    // MARK: - Expression poses

    private func apply(_ expression: PetExpression, to head: Entity, animated: Bool) {
        let mouth = head.findEntity(named: ProceduralHeadBuilder.mouthName)
        let leftBrow = head.findEntity(named: ProceduralHeadBuilder.leftBrowName)
        let rightBrow = head.findEntity(named: ProceduralHeadBuilder.rightBrowName)
        let leftLid = head.findEntity(named: ProceduralHeadBuilder.leftLidName)
        let rightLid = head.findEntity(named: ProceduralHeadBuilder.rightLidName)
        let leftEye = head.findEntity(named: ProceduralHeadBuilder.leftEyeName)
        let rightEye = head.findEntity(named: ProceduralHeadBuilder.rightEyeName)
        let skull = head.findEntity(named: ProceduralHeadBuilder.skullName) as? ModelEntity

        var mouthScale = SIMD3<Float>(baseMouthWidth, 1, 1)
        var mouthPosition = neutralMouthPosition
        var browY = neutralBrowY
        var browTilt: Float = 0
        var lidScaleY: Float = 0.05
        var eyeScale = SIMD3<Float>(1, 1, 1)
        var skin = baseSkin

        switch expression {
        case .neutral:
            break
        case .happy:
            mouthScale = [baseMouthWidth * 1.25, 0.7, 1]
            mouthPosition.y = -0.04
            browY = 0.065
            browTilt = -0.15
        case .sad:
            mouthScale = [baseMouthWidth * 0.9, 0.7, 1]
            mouthPosition.y = -0.052
            browY = 0.055
            browTilt = 0.25
            lidScaleY = 0.35
        case .hungry:
            mouthScale = [baseMouthWidth * 0.7, 1.4, 1]
            mouthPosition.y = -0.05
            eyeScale = [1.05, 1.1, 1]
        case .sleepy:
            mouthScale = [baseMouthWidth * 0.85, 0.5, 1]
            lidScaleY = 0.75
            browY = 0.05
            eyeScale = [1, 0.7, 1]
        case .sick:
            mouthScale = [baseMouthWidth * 0.75, 0.6, 1]
            mouthPosition.y = -0.05
            browY = 0.052
            browTilt = 0.2
            lidScaleY = 0.4
            skin = UIColor(red: 0.78, green: 0.88, blue: 0.78, alpha: 1)
        case .distressed:
            mouthScale = [baseMouthWidth * 0.95, 1.15, 1]
            mouthPosition.y = -0.048
            browY = 0.07
            browTilt = 0.35
            lidScaleY = 0.15
            eyeScale = [1.12, 1.18, 1]
            skin = UIColor(red: 0.98, green: 0.78, blue: 0.72, alpha: 1)
        case .deceased:
            mouthScale = [baseMouthWidth * 0.8, 0.35, 1]
            lidScaleY = 1.0
            browY = 0.05
            eyeScale = [1, 0.4, 1]
            skin = UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1)
        }

        let duration: TimeInterval = animated && !reduceMotion ? 0.28 : 0

        move(mouth, position: mouthPosition, scale: mouthScale, duration: duration)
        move(leftEye, scale: baseEyeScale * eyeScale, duration: duration)
        move(rightEye, scale: baseEyeScale * eyeScale, duration: duration)
        move(leftLid, scale: [1, lidScaleY, 1], duration: duration)
        move(rightLid, scale: [1, lidScaleY, 1], duration: duration)

        if let leftBrow {
            var t = leftBrow.transform
            t.translation = [leftEyeRest.x, browY, 0.105]
            t.rotation = simd_quatf(angle: browTilt, axis: [0, 0, 1])
            applyTransform(leftBrow, t, duration: duration)
        }
        if let rightBrow {
            var t = rightBrow.transform
            t.translation = [rightEyeRest.x, browY, 0.105]
            t.rotation = simd_quatf(angle: -browTilt, axis: [0, 0, 1])
            applyTransform(rightBrow, t, duration: duration)
        }

        if let skull {
            skull.model?.materials = [SimpleMaterial(color: skin, roughness: 0.55, isMetallic: false)]
        }
    }

    // MARK: - Autonomous animations

    private func startBlinkLoop() {
        blinkTask?.cancel()
        blinkTask = Task { [weak self] in
            while !Task.isCancelled {
                let delay = UInt64.random(in: 2_400_000_000...4_800_000_000)
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                await self?.blinkOnce()
            }
        }
    }

    private func blinkOnce() async {
        guard let head = headRoot else { return }
        if currentExpression == .deceased { return }

        isBlinking = true
        defer { isBlinking = false }

        let leftLid = head.findEntity(named: ProceduralHeadBuilder.leftLidName)
        let rightLid = head.findEntity(named: ProceduralHeadBuilder.rightLidName)
        let closed = SIMD3<Float>(1, 1, 1)
        let openY = openLidScaleY(for: currentExpression)
        let open = SIMD3<Float>(1, openY, 1)

        move(leftLid, scale: closed, duration: 0.08)
        move(rightLid, scale: closed, duration: 0.08)
        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !Task.isCancelled else { return }
        move(leftLid, scale: open, duration: 0.1)
        move(rightLid, scale: open, duration: 0.1)
    }

    private func openLidScaleY(for expression: PetExpression) -> Float {
        switch expression {
        case .sleepy: return 0.75
        case .sad, .sick: return 0.35
        case .distressed: return 0.15
        case .deceased: return 1.0
        default: return 0.05
        }
    }

    private func startIdleMotion() {
        idleTask?.cancel()
        guard !reduceMotion else { return }
        idleTask = Task { [weak self] in
            var t: Float = 0
            var gazeX: Float = 0
            var gazeY: Float = 0
            var targetGazeX: Float = 0
            var targetGazeY: Float = 0
            var gazeHoldFrames = 0

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                guard let self, let head = self.headRoot else { return }
                t += 0.04

                let bobY = sin(t) * 0.012
                let yaw = sin(t * 0.5) * 0.04
                let pitch = sin(t * 0.37) * 0.025
                head.position.y = bobY
                head.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0])
                    * simd_quatf(angle: yaw, axis: [0, 1, 0])

                if gazeHoldFrames <= 0 {
                    targetGazeX = Float.random(in: -0.006...0.006)
                    targetGazeY = Float.random(in: -0.004...0.004)
                    gazeHoldFrames = Int.random(in: 45...110)
                } else {
                    gazeHoldFrames -= 1
                }

                gazeX += (targetGazeX - gazeX) * 0.06
                gazeY += (targetGazeY - gazeY) * 0.06

                let allowGaze = !self.isBlinking && self.allowsGaze(for: self.currentExpression)
                let appliedX = allowGaze ? gazeX : 0
                let appliedY = allowGaze ? gazeY : 0

                if let leftEye = head.findEntity(named: ProceduralHeadBuilder.leftEyeName) {
                    leftEye.position = self.leftEyeRest + SIMD3<Float>(appliedX, appliedY, 0)
                }
                if let rightEye = head.findEntity(named: ProceduralHeadBuilder.rightEyeName) {
                    rightEye.position = self.rightEyeRest + SIMD3<Float>(appliedX, appliedY, 0)
                }
            }
        }
    }

    private func allowsGaze(for expression: PetExpression) -> Bool {
        switch expression {
        case .sleepy, .deceased:
            return false
        default:
            return true
        }
    }

    private func resetIdlePose() {
        guard let head = headRoot else { return }
        head.position.y = 0
        head.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        head.findEntity(named: ProceduralHeadBuilder.leftEyeName)?.position = leftEyeRest
        head.findEntity(named: ProceduralHeadBuilder.rightEyeName)?.position = rightEyeRest
    }

    // MARK: - Helpers

    private func move(
        _ entity: Entity?,
        position: SIMD3<Float>? = nil,
        scale: SIMD3<Float>? = nil,
        duration: TimeInterval
    ) {
        guard let entity else { return }
        var t = entity.transform
        if let position { t.translation = position }
        if let scale { t.scale = scale }
        applyTransform(entity, t, duration: duration)
    }

    private func applyTransform(_ entity: Entity, _ transform: Transform, duration: TimeInterval) {
        if duration <= 0 {
            entity.transform = transform
            return
        }
        entity.move(to: transform, relativeTo: entity.parent, duration: duration, timingFunction: .easeInOut)
    }
}
