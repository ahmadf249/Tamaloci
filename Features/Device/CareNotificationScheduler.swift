import Foundation
import UserNotifications

/// Local care / critical reminders. Fully optional — deny permission and gameplay continues.
@MainActor
final class CareNotificationScheduler {
    static let shared = CareNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let criticalID = "tamaloci.care.critical"
    private let hungerID = "tamaloci.care.hunger"
    private let illID = "tamaloci.care.ill"
    private var didRequestAuth = false

    func requestAuthorizationIfNeeded() async {
        guard AppPreferences.careNotificationsEnabled else { return }
        guard !didRequestAuth else { return }
        didRequestAuth = true
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func sync(pet: PetRecord?, config: SimulationConfig = .default) async {
        guard AppPreferences.careNotificationsEnabled else {
            cancelAllCareReminders()
            return
        }

        await requestAuthorizationIfNeeded()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            cancelAllCareReminders()
            return
        }

        guard let pet, pet.state.lifecycleStatus == .active else {
            cancelAllCareReminders()
            return
        }

        if pet.needs.health <= config.criticalHealthThreshold {
            await schedule(
                id: criticalID,
                title: "\(pet.name) needs care",
                body: "Health is low — check on your pet.",
                afterSeconds: 60 * 30
            )
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [criticalID])
        }

        if pet.needs.hunger <= config.criticalThreshold {
            await schedule(
                id: hungerID,
                title: "\(pet.name) is hungry",
                body: "A snack would help.",
                afterSeconds: 60 * 45
            )
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [hungerID])
        }

        if pet.state.isIll {
            await schedule(
                id: illID,
                title: "\(pet.name) feels ill",
                body: "Medicine can help them recover.",
                afterSeconds: 60 * 20
            )
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [illID])
        }
    }

    private func cancelAllCareReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [criticalID, hungerID, illID])
    }

    private func schedule(id: String, title: String, body: String, afterSeconds: TimeInterval) async {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = AppPreferences.soundEnabled ? .default : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(afterSeconds, 5), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
