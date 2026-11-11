import XCTest
@testable import Tamaloci

final class PetExpressionTests: XCTestCase {
    func testRequiredExpressionsMatchSpec() {
        let expected: [PetExpression] = [
            .neutral, .happy, .sad, .hungry, .sleepy, .sick, .deceased
        ]
        XCTAssertEqual(PetExpression.allCases, expected)
    }

    func testDisplayNamesAreNonEmpty() {
        for expression in PetExpression.allCases {
            XCTAssertFalse(expression.displayName.isEmpty)
        }
    }

    func testNeedsStubDefaultsAreInValidRange() {
        let needs = PetNeeds.neutralDefaults
        for value in [
            needs.hunger, needs.hydration, needs.happiness,
            needs.health, needs.cleanliness, needs.energy
        ] {
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 100)
        }
    }
}
