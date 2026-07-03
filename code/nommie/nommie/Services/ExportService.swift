import SwiftUI
import UIKit
import Photos

enum ExportFormat {
    case post   // 1:1 square — Instagram feed
    case story  // 9:16 tall — Instagram & TikTok stories

    var previewRatio: CGFloat {
        switch self {
        case .post:   return 1.0
        case .story:  return 9.0 / 16.0
        }
    }

    // Natural card dimensions in points (rendered at 3× scale for export pixels)
    var naturalSize: CGSize {
        switch self {
        case .post:   return CGSize(width: 390, height: 390)
        case .story:  return CGSize(width: 390, height: 693)
        }
    }

    var rendererSize: ProposedViewSize {
        ProposedViewSize(width: naturalSize.width, height: naturalSize.height)
    }
}

class ExportService {

    func exportCard(recipe: Recipe, format: ExportFormat, perServing: Bool = false, preloadedImage: UIImage? = nil, palette: CardPalette = CardPalettes.neutral) async throws -> UIImage {
        let cardView = ExportCardView(recipe: recipe, format: format, perServing: perServing, preloadedImage: preloadedImage, palette: palette)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        renderer.proposedSize = format.rendererSize

        guard let image = renderer.uiImage else {
            throw ExportError.renderFailed
        }
        return image
    }

    func saveToPhotoLibrary(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.saveFailed
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    func shareImage(_ image: UIImage, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        viewController.present(activityVC, animated: true)
    }
}

enum ExportError: LocalizedError {
    case renderFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed: return "Couldn't render your recipe card. Please try again."
        case .saveFailed:   return "Couldn't save to your camera roll. Please check your photo permissions."
        }
    }
}

// MARK: - Export Card View

struct ExportCardView: View {
    let recipe: Recipe
    let format: ExportFormat
    var perServing: Bool = false
    var preloadedImage: UIImage? = nil
    var palette: CardPalette = CardPalettes.neutral

    private var bg: Color     { palette.background }
    private var accent: Color { palette.accent }
    private var macros: Macros { recipe.displayMacros(perServing: perServing) }
    private var suffix: String { perServing ? "/srv" : "" }

    // MARK: Sub-views

    @ViewBuilder
    private var heroImage: some View {
        Color.clear
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
                Group {
                    if let img = preloadedImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Rectangle()
                            .fill(accent.opacity(0.08))
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 28))
                                    .foregroundColor(accent.opacity(0.25))
                            )
                    }
                }
                .clipped()
            )
    }

    // size: "small" (post small text), "medium" (post main), "large" (story)
    @ViewBuilder
    private func dishInfoBlock(size: String = "small") -> some View {
        let dishSize: CGFloat = size == "large" ? 17 : (size == "medium" ? 15 : 13)
        let starSize: CGFloat = size == "large" ? 10 : (size == "medium" ? 9  : 7)
        let timeSize: CGFloat = size == "large" ? 11 : (size == "medium" ? 10 : 8)
        let tagSize:  CGFloat = size == "large" ? 11 : (size == "medium" ? 10 : 8)
        let tagPadH:  CGFloat = size == "large" ? 8  : (size == "medium" ? 7  : 6)
        let tagPadV:  CGFloat = size == "large" ? 3  : 2
        let vspacing: CGFloat = size == "large" ? 6  : (size == "medium" ? 6  : 5)

        VStack(alignment: .leading, spacing: vspacing) {
            Text(recipe.dishName)
                .font(Font.custom("Lora-Bold", size: dishSize))
                .foregroundColor(.nommieBrown)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= recipe.prepTimeStars ? "star.fill" : "star")
                        .font(.system(size: starSize))
                        .foregroundColor(i <= recipe.prepTimeStars ? Color(hex: "E0A930") : .nommieBrown.opacity(0.2))
                }
                Text(recipe.prepTimeLabel)
                    .font(Font.custom("Nunito-Regular", size: timeSize))
                    .foregroundColor(.nommieBrown.opacity(0.45))
                if recipe.servings > 1 {
                    Text("· \(recipe.servings) srv")
                        .font(Font.custom("Nunito-Regular", size: timeSize))
                        .foregroundColor(.nommieBrown.opacity(0.45))
                }
            }

            HStack(spacing: 0) {
                ExportMacroPill(label: "CAL\(suffix)", value: "\(macros.calories)", accent: accent, size: size)
                ExportMacroPill(label: "PRO\(suffix)", value: "\(macros.protein)g",  accent: accent, size: size)
                ExportMacroPill(label: "CARB\(suffix)", value: "\(macros.carbs)g",   accent: accent, size: size)
                ExportMacroPill(label: "FAT\(suffix)", value: "\(macros.fat)g",      accent: accent, size: size)
                ExportMacroPill(label: "FIB\(suffix)", value: "\(macros.fiber)g",    accent: accent, size: size)
                ExportMacroPill(label: "SUG\(suffix)", value: "\(macros.sugar)g",    accent: accent, size: size)
            }

            if !recipe.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(recipe.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(Font.custom("Nunito-Regular", size: tagSize))
                            .foregroundColor(accent)
                            .lineLimit(1)
                            .padding(.horizontal, tagPadH)
                            .padding(.vertical, tagPadV)
                            .background(Capsule().fill(accent.opacity(0.12)))
                            .fixedSize()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func ingredientsBlock(lineLimit: Int) -> some View {
        if !recipe.ingredients.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ingredients")
                    .font(Font.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(accent)
                    .padding(.bottom, 2)

                let shown = Array(recipe.ingredients.prefix(6))
                ForEach(shown) { ingredient in
                    HStack(alignment: .top, spacing: 5) {
                        Circle()
                            .fill(accent)
                            .frame(width: 4, height: 4)
                            .padding(.top, 4)
                        Text(ingredient.quantity.isEmpty
                             ? ingredient.name
                             : "\(ingredient.quantity) \(ingredient.name)")
                            .font(Font.custom("Nunito-Regular", size: 11))
                            .foregroundColor(.nommieBrown.opacity(0.8))
                            .lineLimit(lineLimit)
                    }
                }

                if recipe.ingredients.count > 6 {
                    Text("+\(recipe.ingredients.count - 6) more")
                        .font(Font.custom("Nunito-Regular", size: 10))
                        .italic()
                        .foregroundColor(accent.opacity(0.6))
                }
            }
        }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            Text("Plated by: @\(recipe.username)")
                .font(Font.custom("Caveat-Regular", size: 14))
                .foregroundColor(accent)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            if format == .story {
                storyLayout
            } else {
                postLayout
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: format == .story ? 690 : 388, alignment: .top)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }

    // MARK: Story layout
    // Image → dish info → [ingredients | QR+nommie] row
    // All elements share the same 14pt horizontal padding so their left edges align.

    @ViewBuilder
    private var storyLayout: some View {
        // Image uses same 14pt padding as everything else so left edges align.
        heroImage
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

        dishInfoBlock(size: "large")
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

        // Ingredients (left) and QR+nommie (right) share a row, bottom-aligned
        // so the last ingredient line sits level with the nommie logo.
        HStack(alignment: .bottom, spacing: 14) {
            ingredientsBlock(lineLimit: 1)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 5) {
                CardQRCode(value: "https://getnommie.app/@\(recipe.username)/\(recipe.id)", size: 44, accent: accent)
                Text("nommie ")
                    .font(Font.custom("Caveat-Bold", size: 18))
                    .foregroundColor(accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: Post layout
    // Row 1: image (left, fills width minus ingredient column) + ingredients (right).
    // Row 2: dish info (left, full width) + QR+nommie (right).
    // This keeps the image as large as possible while fitting bigger text in the fixed 390×390 card.

    @ViewBuilder
    private var postLayout: some View {
        // Row 1: image + ingredients
        HStack(alignment: .top, spacing: 4) {
            heroImage
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity)

            ingredientsBlock(lineLimit: 2)
                .frame(width: 110)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)

        // Row 2: dish info + QR+nommie, bottom-aligned so QR sits at card bottom
        HStack(alignment: .bottom, spacing: 10) {
            dishInfoBlock(size: "medium")
                .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 5) {
                CardQRCode(value: "https://getnommie.app/@\(recipe.username)/\(recipe.id)", size: 40, accent: accent)
                Text("nommie ")
                    .font(Font.custom("Caveat-Bold", size: 16))
                    .foregroundColor(accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}

// MARK: - Export Macro Pill

struct ExportMacroPill: View {
    let label: String
    let value: String
    let accent: Color
    var size: String = "small"  // "small" | "medium" | "large"

    var body: some View {
        VStack(spacing: size == "large" ? 2 : 1) {
            Text(value)
                .font(Font.custom("Nunito-Bold", size: size == "large" ? 15 : (size == "medium" ? 13 : 11)))
                .foregroundColor(.nommieBrown)
            Text(label)
                .font(Font.custom("Nunito-Regular", size: size == "large" ? 9 : (size == "medium" ? 8 : 7)))
                .foregroundColor(.nommieBrown.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, size == "large" ? 7 : (size == "medium" ? 6 : 5))
        .background(accent.opacity(0.08))
        .overlay(Rectangle().stroke(accent.opacity(0.12), lineWidth: 0.5))
    }
}
