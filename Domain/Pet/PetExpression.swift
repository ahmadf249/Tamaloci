import Foundation

/// Gameplay facial expressions required by the Phase I / PDF §3.5 animation proof.
/// Simulation state (not live ARKit face tracking) will drive these later.
enum PetExpression: String, CaseIterable, Identifiable, Sendable {
    case neutral
    case happy
    case sad
    case hungry
    case sleepy
    case sick
    case deceased

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutral: return "Neutral"
        case .happy: return "Happy"
        case .sad: return "Sad"
        case .hungry: return "Hungry"
        case .sleepy: return "Sleepy"
        case .sick: return "Sick"
        case .deceased: return "Deceased"
        }
    }
}
