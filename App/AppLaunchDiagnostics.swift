import Foundation

/// Set at launch when the durable SwiftData store cannot open.
enum AppLaunchDiagnostics {
    static var usedInMemoryStore = false
    static var storeErrorDescription: String?
}
