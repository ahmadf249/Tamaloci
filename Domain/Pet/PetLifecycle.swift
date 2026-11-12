import Foundation

/// Lifecycle enums for persistence + future simulation (M4/M5).
enum PetLifecycleState: String, Codable, Sendable {
    case active
    case deceased
}

enum PetLifeStage: String, Codable, CaseIterable, Sendable {
    case baby
    case child
    case teenager
    case adult
}

enum PetSleepSource: String, Codable, Sendable {
    case manual
    case charging
    case scheduled
}
