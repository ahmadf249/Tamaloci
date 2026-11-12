import AudioToolbox
import Foundation

/// Short procedural system sounds for care feedback (ASSET_POLICY — no paid packs).
enum CareSoundPlayer {
    /// Soft tap / confirm.
    private static let careSuccessSoundID: SystemSoundID = 1104

    static func playCareSuccessIfEnabled() {
        guard AppPreferences.soundEnabled else { return }
        AudioServicesPlaySystemSound(careSuccessSoundID)
    }
}
