import Foundation

/// Stub for PDF §7.3 — Phase I does not advance lifecycle yet.
enum PetLifecycleState: String, Sendable {
    case active
    case deceased
}

enum PetLifeStage: String, CaseIterable, Sendable {
    case baby
    case child
    case teenager
    case adult
}

enum PetSleepSource: String, Sendable {
    case manual
    case charging
    case scheduled
}
