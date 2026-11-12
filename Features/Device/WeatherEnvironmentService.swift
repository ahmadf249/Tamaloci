import CoreLocation
import Foundation
import WeatherKit

/// Best-effort WeatherKit fetch. Failures return nil (offline / denied / no entitlement).
@MainActor
final class WeatherEnvironmentService: NSObject {
    static let shared = WeatherEnvironmentService()

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    func fetchCurrentSnapshot(timeoutSeconds: TimeInterval = 4) async -> EnvironmentSnapshotRecord? {
        let started = Date()
        guard let location = await requestLocation() else { return nil }
        let remaining = timeoutSeconds - Date().timeIntervalSince(started)
        guard remaining > 0 else { return nil }

        return await withTaskGroup(of: EnvironmentSnapshotRecord?.self) { group in
            group.addTask {
                await self.fetchWeather(at: location)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
    }

    private func fetchWeather(at location: CLLocation) async -> EnvironmentSnapshotRecord? {
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            return EnvironmentSnapshotRecord(
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                conditionCode: String(describing: current.condition),
                capturedAt: Date()
            )
        } catch {
            return nil
        }
    }

    private func requestLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            // After prompt, try once more briefly.
            try? await Task.sleep(nanoseconds: 800_000_000)
        case .denied, .restricted:
            return nil
        default:
            break
        }

        if let cached = locationManager.location {
            return cached
        }

        locationManager.delegate = self
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if let cont = self.locationContinuation {
                    self.locationContinuation = nil
                    cont.resume(returning: self.locationManager.location)
                }
            }
        }
    }
}

extension WeatherEnvironmentService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let cont = locationContinuation else { return }
            locationContinuation = nil
            cont.resume(returning: locations.last ?? manager.location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let cont = locationContinuation else { return }
            locationContinuation = nil
            cont.resume(returning: nil)
        }
    }
}
