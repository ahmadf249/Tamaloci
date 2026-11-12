import XCTest
@testable import Tamaloci

final class AvatarConfigurationTests: XCTestCase {
    func testCodableRoundTripIncludesLikenessFields() throws {
        let original = AvatarConfiguration(
            skinTint: AvatarColor(red: 0.9, green: 0.7, blue: 0.55, alpha: 1),
            hairColor: AvatarColor(red: 0.1, green: 0.08, blue: 0.05),
            irisColor: AvatarColor(red: 0.2, green: 0.4, blue: 0.6),
            eyeScale: 1.2,
            browScale: 0.9,
            headWidth: 1.1,
            jawWidth: 0.95,
            eyeSpacing: 1.05,
            noseScale: 1.1,
            mouthWidth: 0.9,
            faceLength: 1.05,
            hairCoverage: 0.7
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AvatarConfiguration.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLegacyDecodeFillsNewMorphDefaults() throws {
        let legacyJSON = """
        {"skinTint":{"red":0.96,"green":0.8,"blue":0.7,"alpha":1},"eyeScale":1.1,"browScale":1.0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AvatarConfiguration.self, from: legacyJSON)
        XCTAssertEqual(decoded.eyeScale, 1.1, accuracy: 0.001)
        XCTAssertEqual(decoded.headWidth, 1, accuracy: 0.001)
        XCTAssertEqual(decoded.hairCoverage, 0.85, accuracy: 0.001)
        XCTAssertEqual(decoded.hairColor, AvatarConfiguration.default.hairColor)
    }

    func testMapperAppliesHairAndIris() {
        let estimate = AvatarParameterMapper.FaceEstimate(
            faceWidth: 1.05,
            jawWidth: 1.02,
            eyeSpacing: 1.0,
            eyeSize: 1.1,
            browScale: 1.0,
            noseScale: 1.0,
            mouthWidth: 1.0,
            faceLength: 1.05,
            hairCoverage: 0.9,
            skinTint: AvatarColor(red: 0.8, green: 0.6, blue: 0.5),
            hairColor: AvatarColor(red: 0.15, green: 0.1, blue: 0.08),
            irisColor: AvatarColor(red: 0.3, green: 0.5, blue: 0.35)
        )
        let config = AvatarParameterMapper.makeConfiguration(from: estimate)
        XCTAssertEqual(config.hairCoverage, 0.9, accuracy: 0.001)
        XCTAssertEqual(config.hairColor.red, 0.15, accuracy: 0.001)
        XCTAssertEqual(config.irisColor.green, 0.5, accuracy: 0.001)
    }

    @MainActor
    func testStoreSaveRestoreRoundTrip() {
        let suiteName = "tamaloci.tests.avatar.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AvatarConfigurationStore(defaults: defaults)
        let custom = AvatarConfiguration(
            skinTint: AvatarColor(red: 0.85, green: 0.65, blue: 0.5),
            eyeScale: 1.15,
            browScale: 1.1,
            headWidth: 1.05,
            jawWidth: 1.02,
            eyeSpacing: 0.95,
            noseScale: 1.1,
            mouthWidth: 1.05,
            faceLength: 1.02,
            hairCoverage: 0.8
        )
        store.save(custom)

        let restoredStore = AvatarConfigurationStore(defaults: defaults)
        XCTAssertEqual(restoredStore.restore(), custom)
    }
}
