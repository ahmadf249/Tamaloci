import Foundation

/// In-memory (optional UserDefaults-backed) store for avatar appearance.
/// Proves save/restore round-trip before SwiftData lands in M3.
@MainActor
final class AvatarConfigurationStore {
    private let defaultsKey = "tamaloci.avatarConfiguration"
    private let defaults: UserDefaults

    private(set) var configuration: AvatarConfiguration

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(AvatarConfiguration.self, from: data) {
            configuration = decoded
        } else {
            configuration = .default
        }
    }

    func save(_ configuration: AvatarConfiguration) {
        self.configuration = configuration
        if let data = try? JSONEncoder().encode(configuration) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    func restore() -> AvatarConfiguration {
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(AvatarConfiguration.self, from: data) {
            configuration = decoded
            return decoded
        }
        return configuration
    }

    /// Test helper: clear persisted bytes while keeping the in-memory value.
    func clearPersisted() {
        defaults.removeObject(forKey: defaultsKey)
    }
}
