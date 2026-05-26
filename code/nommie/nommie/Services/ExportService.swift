import SwiftUI
import UIKit

enum ExportFormat {
    case story
    case square
    
    var size: CGSize {
        switch self {
        case .story:
            return CGSize(width: 1080, height: 1920)
        case .square:
            return CGSize(width: 1080, height: 1080)
        }
    }
}

class ExportService {
    
    func exportCard(recipe: Recipe, format: ExportFormat, preloadedImage: UIImage? = nil) async throws -> UIImage {
        let cardView = ExportCardView(recipe: recipe, format: format, preloadedImage: preloadedImage)
        
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        
        switch format {
        case .story:
            renderer.proposedSize = ProposedViewSize(width: 390, height: 693)
        case .square:
            renderer.proposedSize = ProposedViewSize(width: 390, height: 390)
        }
        
        guard let image = renderer.uiImage else {
            throw ExportError.renderFailed
        }
        
        return image
    }
    
    func saveToPhotoLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { continuation in
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            continuation.resume()
        }
    }
    
    func shareImage(_ image: UIImage, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        viewController.present(activityVC, animated: true)
    }
}

enum ExportError: LocalizedError {
    case renderFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Couldn't render your recipe card. Please try again."
        case .saveFailed:
            return "Couldn't save to your camera roll. Please check your photo permissions."
        }
    }
}

// MARK: - Export Card View
struct ExportCardView: View {
    let recipe: Recipe
    let format: ExportFormat
    var preloadedImage: UIImage? = nil
    
    var themeBackground: Color {
        switch recipe.theme {
        case "sage": return Color(hex: "EDF0EB")
        case "blush": return Color(hex: "FAF0F0")
        default: return Color(hex: "F5F0E8")
        }
    }
    
    var themeAccent: Color {
        switch recipe.theme {
        case "sage": return Color(hex: "4A6741")
        case "blush": return Color(hex: "C87E8A")
        default: return Color(hex: "3A5C44")
        }
    }
    
    var body: some View {
        ZStack {
            themeBackground
            
            VStack(alignment: .leading, spacing: 0) {
                // Plated by header
                Text("Plated by: @\(recipe.username)")
                    .font(NommieFont.signature.font())
                    .foregroundColor(themeAccent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                
                // Hero image
                if let uiImage = preloadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: format == .story ? 320 : 200)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(themeAccent.opacity(0.1))
                        .frame(maxWidth: .infinity)
                        .frame(height: format == .story ? 320 : 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(themeAccent.opacity(0.3))
                        )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.dishName)
                        .font(NommieFont.titleMedium.font())
                        .foregroundColor(.nommieBrown)
                    
                    // Macro row
                    HStack(spacing: 0) {
                        ExportMacroPill(label: "Cal", value: "\(recipe.macros.calories)", accent: themeAccent)
                        ExportMacroPill(label: "Protein", value: "\(recipe.macros.protein)g", accent: themeAccent)
                        ExportMacroPill(label: "Carbs", value: "\(recipe.macros.carbs)g", accent: themeAccent)
                        ExportMacroPill(label: "Fat", value: "\(recipe.macros.fat)g", accent: themeAccent)
                    }
                    
                    // Tags
                    if !recipe.tags.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(recipe.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(themeAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(themeAccent.opacity(0.1)))
                            }
                        }
                    }
                    
                    // Watermark
                    HStack {
                        Spacer()
                        Text("nommie")
                            .font(NommieFont.caption.font())
                            .foregroundColor(themeAccent.opacity(0.4))
                    }
                }
                .padding(20)
            }
        }
        // No corner radius for export
    }
}

struct ExportMacroPill: View {
    let label: String
    let value: String
    let accent: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(NommieFont.bodySemiBold.font())
                .foregroundColor(.nommieBrown)
            Text(label)
                .font(NommieFont.caption.font())
                .foregroundColor(.nommieBrown.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(accent.opacity(0.06))
        .overlay(
            Rectangle()
                .stroke(accent.opacity(0.1), lineWidth: 0.5)
        )
    }
}
