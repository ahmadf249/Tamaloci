import Foundation

/// Lifecycle enums for persistence + future simulation (M4/M5).
enum PetLifecycleState: String, Codable, Sendable {
    case active
    case deceased
}

enum PetLifeStage: String, Codable, CaseIterable, Sendable, Comparable {
    case baby
    case child
    case teenager
    case adult

    private var rank: Int {
        switch self {
        case .baby: return 0
        case .child: return 1
        case .teenager: return 2
        case .adult: return 3
        }
    }

    static func < (lhs: PetLifeStage, rhs: PetLifeStage) -> Bool {
        lhs.rank < rhs.rank
    }

    var displayName: String {
        switch self {
        case .baby: return "Baby"
        case .child: return "Child"
        case .teenager: return "Teenager"
        case .adult: return "Adult"
        }
    }
}

enum PetSleepSource: String, Codable, Sendable {
    case manual
    case charging
    case scheduled
}
