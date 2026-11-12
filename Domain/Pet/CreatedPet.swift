import Foundation

/// Lightweight first-run pet record (UserDefaults until SwiftData in M3).
struct CreatedPet: Equatable, Codable, Sendable {
    var name: String
    var avatarConfiguration: AvatarConfiguration
    var createdAt: Date

    var hasCompletedOnboarding: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
