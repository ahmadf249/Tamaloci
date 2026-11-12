import Foundation

/// User-facing prefs (UserDefaults / AppStorage). Defaults are on.
enum AppPreferences {
    static let hapticsEnabledKey = "tamaloci.prefs.hapticsEnabled"
    static let soundEnabledKey = "tamaloci.prefs.soundEnabled"
    static let careNotificationsEnabledKey = "tamaloci.prefs.careNotificationsEnabled"

    static var hapticsEnabled: Bool {
        if UserDefaults.standard.object(forKey: hapticsEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: hapticsEnabledKey)
    }

    static var soundEnabled: Bool {
        if UserDefaults.standard.object(forKey: soundEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: soundEnabledKey)
    }

    static var careNotificationsEnabled: Bool {
        if UserDefaults.standard.object(forKey: careNotificationsEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: careNotificationsEnabledKey)
    }
}
