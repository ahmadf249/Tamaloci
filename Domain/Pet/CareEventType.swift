import Foundation

enum CareEventType: String, Codable, CaseIterable, Sendable {
    case feed
    case water
    case play
    case clean
    case medicine
    case sleep
    case wake

    var displayName: String {
        switch self {
        case .feed: return "Feed"
        case .water: return "Water"
        case .play: return "Play"
        case .clean: return "Clean"
        case .medicine: return "Medicine"
        case .sleep: return "Sleep"
        case .wake: return "Wake"
        }
    }
}
