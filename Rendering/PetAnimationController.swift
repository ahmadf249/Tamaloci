import Foundation
import RealityKit
import UIKit

/// Drives facial expressions on the procedural head. Kept free of SwiftUI so the
/// future pet simulation can call `setExpression(_:)` directly (PDF §3.5, §7.1).
@MainActor
final class PetAnimationController {
    private(set) var currentExpression: PetExpression = .neutral
    private weak var headRoot: Entity?
    private var blinkTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var reduceMotion: Bool = false

    private let neutralMouthScale = SIMD3<Float>(1, 1, 1)
    private let neutralMouthPosition = SIMD3<Float>(0, -0.045, 0.11)
    private let neutralBrowY: Float = 0.06

    func attach(to headRoot: Entity, reduceMotion: Bool) {
        self.headRoot = headRoot
        self.reduceMotion = reduceMotion
        setExpression(.neutral, animated: false)
        startBlinkLoop()
        startIdleFloat()
    }

    func updateReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        if enabled {
            idleTask?.cancel()
            idleTask = nil
            headRoot?.position.y = 0
        } else if idleTask == nil {
            startIdleFloat()
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

        var mouthScale = neutralMouthScale
        var mouthPosition = neutralMouthPosition
        var browY = neutralBrowY
        var browTilt: Float = 0
        var lidScaleY: Float = 0.05
        var eyeScale = SIMD3<Float>(1, 1, 1)
        var skin = UIColor(red: 0.96, green: 0.80, blue: 0.70, alpha: 1)

        switch expression {
        case .neutral:
            break
        case .happy:
            mouthScale = [1.25, 0.7, 1]
            mouthPosition.y = -0.04
            browY = 0.065
            browTilt = -0.15
        case .sad:
            mouthScale = [0.9, 0.7, 1]
            mouthPosition.y = -0.052
            browY = 0.055
            browTilt = 0.25
            lidScaleY = 0.35
        case .hungry:
            mouthScale = [0.7, 1.4, 1]
            mouthPosition.y = -0.05
            eyeScale = [1.05, 1.1, 1]
        case .sleepy:
            mouthScale = [0.85, 0.5, 1]
            lidScaleY = 0.75
            browY = 0.05
            eyeScale = [1, 0.7, 1]
        case .sick:
            mouthScale = [0.75, 0.6, 1]
            mouthPosition.y = -0.05
            browY = 0.052
            browTilt = 0.2
            lidScaleY = 0.4
            skin = UIColor(red: 0.78, green: 0.88, blue: 0.78, alpha: 1)
        case .deceased:
            mouthScale = [0.8, 0.35, 1]
            lidScaleY = 1.0
            browY = 0.05
            eyeScale = [1, 0.4, 1]
            skin = UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1)
        }

        let duration: TimeInterval = animated && !reduceMotion ? 0.28 : 0

        move(mouth, position: mouthPosition, scale: mouthScale, duration: duration)
        move(leftEye, scale: eyeScale, duration: duration)
        move(rightEye, scale: eyeScale, duration: duration)
        move(leftLid, scale: [1, lidScaleY, 1], duration: duration)
        move(rightLid, scale: [1, lidScaleY, 1], duration: duration)

        if let leftBrow {
            var t = leftBrow.transform
            t.translation = [-0.04, browY, 0.105]
            t.rotation = simd_quatf(angle: browTilt, axis: [0, 0, 1])
            applyTransform(leftBrow, t, duration: duration)
        }
        if let rightBrow {
            var t = rightBrow.transform
            t.translation = [0.04, browY, 0.105]
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
        // Skip blink while deceased or fully sleepy lids are already closed.
        if currentExpression == .deceased { return }

        let leftLid = head.findEntity(named: ProceduralHeadBuilder.leftLidName)
        let rightLid = head.findEntity(named: ProceduralHeadBuilder.rightLidName)
        let closed = SIMD3<Float>(1, 1, 1)
        let openY: Float = currentExpression == .sleepy ? 0.75 : (currentExpression == .sad || currentExpression == .sick ? 0.35 : 0.05)
        let open = SIMD3<Float>(1, openY, 1)

        move(leftLid, scale: closed, duration: 0.08)
        move(rightLid, scale: closed, duration: 0.08)
        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !Task.isCancelled else { return }
        move(leftLid, scale: open, duration: 0.1)
        move(rightLid, scale: open, duration: 0.1)
    }

    private func startIdleFloat() {
        idleTask?.cancel()
        guard !reduceMotion else { return }
        idleTask = Task { [weak self] in
            var t: Float = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                guard let self, let head = self.headRoot else { return }
                t += 0.04
                head.position.y = sin(t) * 0.012
                head.orientation = simd_quatf(angle: sin(t * 0.5) * 0.04, axis: [0, 1, 0])
            }
        }
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
