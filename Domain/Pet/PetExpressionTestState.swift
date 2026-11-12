import Foundation
import Observation

/// Dev/test driver for facial expressions. Supplies pet state to the renderer
/// without ARKit or live face tracking (M1.2).
@MainActor
@Observable
final class PetExpressionTestState {
    var expression: PetExpression

    init(expression: PetExpression = .neutral) {
        self.expression = expression
    }

    func setExpression(_ expression: PetExpression) {
        self.expression = expression
    }
}
