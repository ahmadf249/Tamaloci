import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(AppPreferences.soundEnabledKey) private var soundEnabled = true
    @AppStorage(AppPreferences.careNotificationsEnabledKey) private var careNotificationsEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    Toggle("Sound", isOn: $soundEnabled)
                    Toggle("Care reminders", isOn: $careNotificationsEnabled)
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Reminders need notification permission. The game stays fully playable if you turn these off or deny access.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    Text("TAMA\"LO\"CI — offline-first companion. Weather, battery, and notifications are optional.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: careNotificationsEnabled) { _, enabled in
                if !enabled {
                    Task { await CareNotificationScheduler.shared.sync(pet: nil) }
                }
            }
        }
        .accessibilityLabel("Settings")
    }
}
