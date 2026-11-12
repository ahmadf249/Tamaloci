import Foundation
import UIKit

/// Foreground-only battery observation for charging sleep. No invented unplug history.
@MainActor
final class BatterySleepMonitor {
    static let shared = BatterySleepMonitor()

    private var didEnableMonitoring = false

    func prepare() {
        guard !didEnableMonitoring else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        didEnableMonitoring = true
    }

    /// `true` when plugged in / full; `false` when unplugged; `nil` if unknown.
    var isCharging: Bool? {
        prepare()
        switch UIDevice.current.batteryState {
        case .charging, .full:
            return true
        case .unplugged:
            return false
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
}
