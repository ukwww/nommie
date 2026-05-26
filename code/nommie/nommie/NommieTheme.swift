import SwiftUI

// MARK: - Colors
extension Color {
    static let nommieBackground = Color(hex: "F5F0E8")
    static let nommieGreen = Color(hex: "3A5C44")
    static let nommieBlush = Color(hex: "C87E8A")
    static let nommieYellow = Color(hex: "E8D98A")
    static let nommieBrown = Color(hex: "4A3728")
    static let nommieWhite = Color.white
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Fonts
enum NommieFont {
    case titleLarge
    case titleMedium
    case titleSmall
    case bodyRegular
    case bodySemiBold
    case bodyBold
    case caption
    case signature

    func font() -> Font {
        switch self {
        case .titleLarge:
            return Font.custom("Lora-Bold", size: 28)
        case .titleMedium:
            return Font.custom("Lora-SemiBold", size: 22)
        case .titleSmall:
            return Font.custom("Lora-Medium", size: 18)
        case .bodyRegular:
            return Font.custom("Nunito-Regular", size: 16)
        case .bodySemiBold:
            return Font.custom("Nunito-SemiBold", size: 16)
        case .bodyBold:
            return Font.custom("Nunito-Bold", size: 16)
        case .caption:
            return Font.custom("Nunito-Regular", size: 13)
        case .signature:
            return Font.custom("Caveat-Regular", size: 18)
        }
    }
}

// MARK: - Constants
enum NommieTheme {
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let card: CGFloat = 20
    }

    enum Shadow {
        static let cardColor = Color.black.opacity(0.08)
        static let cardRadius: CGFloat = 12
        static let cardX: CGFloat = 0
        static let cardY: CGFloat = 4
    }

    enum Padding {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
}
