import Foundation

/// Latest care timestamps used for soft meal/drink/clean intervals (pure data).
struct CareRecency: Equatable, Sendable {
    var lastFeedAt: Date?
    var lastWaterAt: Date?
    var lastCleanAt: Date?

    static let empty = CareRecency(lastFeedAt: nil, lastWaterAt: nil, lastCleanAt: nil)
}
