import SwiftUI

struct CardPalette: Equatable {
    let id: String
    let name: String
    let background: Color
    let accent: Color

    static func == (lhs: CardPalette, rhs: CardPalette) -> Bool { lhs.id == rhs.id }
}

enum CardPalettes {
    // Neutral — the default nommie look (always used for your own plates in-app).
    static let neutral = CardPalette(id: "neutral", name: "Sage",
        background: Color(hex: "EDE8DC"), accent: Color(hex: "3A5C44"))

    // Palettes assigned to other users; stable per userId.
    static let others: [CardPalette] = [
        CardPalette(id: "sage",     name: "Forest", background: Color(hex: "DCE8DD"), accent: Color(hex: "4A6741")),
        CardPalette(id: "blush",    name: "Blush",  background: Color(hex: "F5E6E6"), accent: Color(hex: "B5677A")),
        CardPalette(id: "butter",   name: "Butter", background: Color(hex: "F3EAD3"), accent: Color(hex: "9C7A2E")),
        CardPalette(id: "lavender", name: "Lilac",  background: Color(hex: "E7E6F2"), accent: Color(hex: "5E5A8C")),
        CardPalette(id: "clay",     name: "Clay",   background: Color(hex: "F0E2D8"), accent: Color(hex: "A35D3E")),
        CardPalette(id: "slate",    name: "Slate",  background: Color(hex: "DDE7EC"), accent: Color(hex: "3F6678")),
    ]

    // All palettes available in the export color picker (neutral first).
    static let exportOptions: [CardPalette] = [neutral] + others

    /// Own plates → neutral. Everyone else → stable color keyed off their userId.
    static func palette(forOwner ownerId: String, currentUserId: String?) -> CardPalette {
        if let currentUserId, ownerId == currentUserId { return neutral }
        return paletteForUser(ownerId)
    }

    static func paletteForUser(_ userId: String) -> CardPalette {
        guard !userId.isEmpty else { return neutral }
        var hash = 5381
        for byte in userId.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return others[abs(hash) % others.count]
    }
}

// MARK: - Prep time helpers
extension Recipe {
    // Time is now a 4-quarter clock (15/30/45/60). Legacy recipes stored up to
    // 5 stars; cap them at the full hour.
    var prepTimeQuarters: Int { min(max(prepTimeStars, 1), 4) }
    var prepTimeMinutes: Int { prepTimeQuarters * 15 }
    var prepTimeLabel: String { "~\(prepTimeMinutes) min" }

    func displayMacros(perServing: Bool) -> Macros {
        guard perServing, servings > 1 else { return macros }
        return Macros(
            calories: macros.calories / servings,
            protein: macros.protein / servings,
            carbs: macros.carbs / servings,
            fat: macros.fat / servings,
            fiber: macros.fiber / servings,
            sugar: macros.sugar / servings
        )
    }
}
