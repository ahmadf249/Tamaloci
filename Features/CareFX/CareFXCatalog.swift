import Foundation

/// Curated Fluent Emoji asset names for care feedback (MIT subset under CareFX).
enum CareFXCatalog {
    static func assetNames(for type: CareEventType) -> [String] {
        switch type {
        case .feed:
            return [
                "CareFX_Hamburger",
                "CareFX_Pizza",
                "CareFX_Spaghetti",
                "CareFX_Sushi",
                "CareFX_RiceBall",
                "CareFX_Taco",
                "CareFX_Croissant",
                "CareFX_CookedRice"
            ]
        case .water:
            return [
                "CareFX_Droplet",
                "CareFX_CupWithStraw",
                "CareFX_BeverageBox",
                "CareFX_BubbleTea",
                "CareFX_Teacup",
                "CareFX_Milk",
                "CareFX_TropicalDrink",
                "CareFX_HotBeverage"
            ]
        case .play:
            return [
                "CareFX_Tennis",
                "CareFX_SoccerBall",
                "CareFX_VideoGame",
                "CareFX_YoYo",
                "CareFX_Balloon",
                "CareFX_Football"
            ]
        case .clean:
            return [
                "CareFX_Soap",
                "CareFX_Sparkles",
                "CareFX_Bathtub",
                "CareFX_Sponge",
                "CareFX_Bubbles"
            ]
        case .medicine:
            return [
                "CareFX_Pill",
                "CareFX_Bandage",
                "CareFX_GreenApple"
            ]
        case .sleep, .wake:
            return []
        }
    }

    static func randomAssetName(for type: CareEventType) -> String? {
        let pool = assetNames(for: type)
        guard !pool.isEmpty else { return nil }
        return pool.randomElement()
    }

    static func visual(for type: CareEventType) -> CareFXVisual? {
        if let asset = randomAssetName(for: type) {
            return .asset(asset)
        }
        switch type {
        case .sleep:
            return .system("moon.zzz.fill")
        case .wake:
            return .system("sun.max.fill")
        default:
            return nil
        }
    }

    static func flashExpression(for type: CareEventType) -> PetExpression {
        switch type {
        case .feed, .water, .play, .clean, .medicine, .wake:
            return .happy
        case .sleep:
            return .sleepy
        }
    }
}
