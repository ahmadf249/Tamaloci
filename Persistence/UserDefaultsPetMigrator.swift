import Foundation
import SwiftData

/// One-shot M2 UserDefaults → SwiftData migration.
enum UserDefaultsPetMigrator {
    private static let createdPetKey = "tamaloci.createdPet"
    private static let avatarKey = "tamaloci.avatarConfiguration"
    private static let migrationFlagKey = "tamaloci.didMigrateCreatedPetToSwiftData"

    @MainActor
    static func migrateIfNeeded(repository: PetRepository, defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: migrationFlagKey) == false else { return }
        guard repository.activePet == nil else {
            defaults.set(true, forKey: migrationFlagKey)
            clearLegacyKeys(defaults)
            return
        }
        guard let data = defaults.data(forKey: createdPetKey),
              let legacy = try? JSONDecoder().decode(CreatedPet.self, from: data),
              legacy.hasCompletedOnboarding else {
            defaults.set(true, forKey: migrationFlagKey)
            return
        }

        do {
            _ = try repository.createPet(
                name: legacy.name,
                avatarConfiguration: legacy.avatarConfiguration,
                createdAt: legacy.createdAt,
                birthDate: legacy.createdAt
            )
            clearLegacyKeys(defaults)
            defaults.set(true, forKey: migrationFlagKey)
        } catch {
            // Leave flag unset so a later launch can retry.
            #if DEBUG
            print("UserDefaultsPetMigrator failed: \(error)")
            #endif
        }
    }

    private static func clearLegacyKeys(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: createdPetKey)
        defaults.removeObject(forKey: avatarKey)
    }
}
