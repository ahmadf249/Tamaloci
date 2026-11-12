import XCTest
@testable import Tamaloci

final class CareFXCatalogTests: XCTestCase {
    func testIconPoolsNonEmptyForPrimaryCare() {
        for type in [CareEventType.feed, .water, .play, .clean, .medicine] {
            XCTAssertFalse(
                CareFXCatalog.assetNames(for: type).isEmpty,
                "Expected icons for \(type)"
            )
        }
    }

    func testRandomPickBelongsToPool() {
        for type in [CareEventType.feed, .water, .play, .clean, .medicine] {
            let pool = CareFXCatalog.assetNames(for: type)
            let pick = CareFXCatalog.randomAssetName(for: type)
            XCTAssertNotNil(pick)
            XCTAssertTrue(pool.contains(pick!))
        }
    }

    func testSleepWakeUseSystemVisuals() {
        XCTAssertTrue(CareFXCatalog.assetNames(for: .sleep).isEmpty)
        XCTAssertTrue(CareFXCatalog.assetNames(for: .wake).isEmpty)
        XCTAssertEqual(CareFXCatalog.visual(for: .sleep), .system("moon.zzz.fill"))
        XCTAssertEqual(CareFXCatalog.visual(for: .wake), .system("sun.max.fill"))
    }

    func testFlashExpressions() {
        XCTAssertEqual(CareFXCatalog.flashExpression(for: .feed), .happy)
        XCTAssertEqual(CareFXCatalog.flashExpression(for: .sleep), .sleepy)
    }
}
