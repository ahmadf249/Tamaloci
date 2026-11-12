import AVFoundation
import Foundation

enum CameraPermission {
    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static var isAuthorized: Bool {
        status == .authorized
    }

    static var isDenied: Bool {
        status == .denied || status == .restricted
    }

    @MainActor
    static func requestAccess() async -> Bool {
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
