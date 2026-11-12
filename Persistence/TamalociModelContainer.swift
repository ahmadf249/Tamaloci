import Foundation
import SwiftData

enum TamalociModelContainer {
    static let schema = Schema([
        SDPet.self,
        SDPetNeeds.self,
        SDPetState.self,
        SDCareEvent.self,
        SDPetMemorial.self,
        SDEnvironmentSnapshot.self
    ])

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Tamaloci",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
