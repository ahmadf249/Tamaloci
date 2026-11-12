import SwiftData
import SwiftUI

@main
struct TamalociApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try TamalociModelContainer.make()
            AppLaunchDiagnostics.usedInMemoryStore = false
            AppLaunchDiagnostics.storeErrorDescription = nil
        } catch {
            // Fall back to in-memory so the app still launches if store migration fails.
            container = try! TamalociModelContainer.make(inMemory: true)
            AppLaunchDiagnostics.usedInMemoryStore = true
            AppLaunchDiagnostics.storeErrorDescription = error.localizedDescription
            #if DEBUG
            print("SwiftData store failed, using in-memory: \(error)")
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
