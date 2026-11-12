import Foundation

/// Persists the created pet for returning-player routing. Not SwiftData (M3).
@MainActor
@Observable
final class CreatedPetStore {
    private let defaultsKey = "tamaloci.createdPet"
    private let defaults: UserDefaults

    private(set) var pet: CreatedPet?

    var hasCompletedOnboarding: Bool {
        pet?.hasCompletedOnboarding == true
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pet = Self.load(from: defaults, key: defaultsKey)
    }

    func save(_ pet: CreatedPet) {
        self.pet = pet
        if let data = try? JSONEncoder().encode(pet) {
            defaults.set(data, forKey: defaultsKey)
        }
        // Keep avatar key in sync for M1 store compatibility.
        AvatarConfigurationStore(defaults: defaults).save(pet.avatarConfiguration)
    }

    func restore() -> CreatedPet? {
        pet = Self.load(from: defaults, key: defaultsKey)
        return pet
    }

    func clear() {
        pet = nil
        defaults.removeObject(forKey: defaultsKey)
    }

    private static func load(from defaults: UserDefaults, key: String) -> CreatedPet? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CreatedPet.self, from: data)
    }
}
