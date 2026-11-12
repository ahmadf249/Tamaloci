import ARKit
import Foundation

enum FaceCaptureCapability {
    /// TrueDepth / face tracking available (physical device with Face ID hardware).
    static var isARFaceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    static var preferredRoute: CaptureRoute {
        if isARFaceTrackingSupported {
            return .arkit
        }
        return .selfie
    }
}

enum CaptureRoute: String, Equatable {
    case arkit
    case selfie
    case manual
}
