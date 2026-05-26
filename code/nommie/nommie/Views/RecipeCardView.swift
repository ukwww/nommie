import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe
    var compact: Bool = false
    var thumbnail: Bool = false
    
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
        if thumbnail {
            thumbnailCard
        } else {
            fullCard
        }
    }
    
    // MARK: - Thumbnail Card (Profile Grid)
    var thumbnailCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geo in
                AsyncImage(url: URL(string: recipe.imageURL)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle()
                                .fill(themeAccent.opacity(0.08))
                            ProgressView()
                                .progressViewStyle(
                                    CircularProgressViewStyle(tint: themeAccent)
                                )
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    case .failure:
                        ZStack {
                            Rectangle()
                                .fill(themeAccent.opacity(0.08))
                            Image(systemName: "fork.knife")
                                .font(.system(size: 24))
                                .foregroundColor(themeAccent.opacity(0.4))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()
            }
            .aspectRatio(1, contentMode: .fit)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.dishName)
                    .font(NommieFont.bodyRegular.font())
                    .foregroundColor(.nommieBrown)
                    .lineLimit(1)
                
                if !recipe.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(recipe.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(Font.custom("Nunito-Regular", size: 10))
                                .foregroundColor(themeAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(themeAccent.opacity(0.1))
                                )
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                .fill(themeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                .stroke(Color.nommieBrown.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: NommieTheme.Shadow.cardColor,
            radius: 8,
            x: 0,
            y: 2
        )
        .clipShape(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium))
    }
    
    // MARK: - Full Card (Feed + Detail)
    var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plated by header
            if !compact {
                Text("Plated by: @\(recipe.username)")
                    .font(NommieFont.signature.font())
                    .foregroundColor(themeAccent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, NommieTheme.Padding.medium)
                    .padding(.top, NommieTheme.Padding.medium)
                    .padding(.bottom, 8)
            }
            
            // Hero image
            AsyncImage(url: URL(string: recipe.imageURL)) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Rectangle()
                            .fill(themeAccent.opacity(0.08))
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: themeAccent)
                            )
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        Rectangle()
                            .fill(themeAccent.opacity(0.08))
                        Image(systemName: "fork.knife")
                            .font(.system(size: 32))
                            .foregroundColor(themeAccent.opacity(0.4))
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 200 : 300)
            .clipped()
            
            // Card content
            VStack(alignment: .leading, spacing: 12) {
                // Plated by for compact feed
                if compact {
                    Text("Plated by: @\(recipe.username)")
                        .font(NommieFont.signature.font())
                        .foregroundColor(themeAccent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                Text(recipe.dishName)
                    .font(compact ? NommieFont.titleSmall.font() : NommieFont.titleMedium.font())
                    .foregroundColor(.nommieBrown)
                    .lineLimit(compact ? 1 : 2)
                
                // Macro row
                HStack(spacing: 0) {
                    MacroPill(label: "Cal", value: "\(recipe.macros.calories)", accent: themeAccent)
                    MacroPill(label: "Protein", value: "\(recipe.macros.protein)g", accent: themeAccent)
                    MacroPill(label: "Carbs", value: "\(recipe.macros.carbs)g", accent: themeAccent)
                    MacroPill(label: "Fat", value: "\(recipe.macros.fat)g", accent: themeAccent)
                }
                
                if !compact {
                    if !recipe.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(recipe.ingredients.prefix(5)) { ingredient in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(themeAccent.opacity(0.4))
                                        .frame(width: 4, height: 4)
                                    Text("\(ingredient.quantity) \(ingredient.name)")
                                        .font(NommieFont.caption.font())
                                        .foregroundColor(.nommieBrown.opacity(0.7))
                                }
                            }
                            if recipe.ingredients.count > 5 {
                                Text("+ \(recipe.ingredients.count - 5) more")
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(themeAccent.opacity(0.6))
                            }
                        }
                    }
                    
                    if !recipe.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recipe.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(NommieFont.caption.font())
                                        .foregroundColor(themeAccent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(themeAccent.opacity(0.1))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(themeAccent.opacity(0.25), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
                
                // Nommie watermark
                HStack {
                    Spacer()
                    Text("nommie")
                        .font(NommieFont.caption.font())
                        .foregroundColor(themeAccent.opacity(0.3))
                }
            }
            .padding(NommieTheme.Padding.medium)
        }
        .background(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                .fill(themeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                .stroke(Color.nommieBrown.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: NommieTheme.Shadow.cardColor,
            radius: NommieTheme.Shadow.cardRadius,
            x: NommieTheme.Shadow.cardX,
            y: NommieTheme.Shadow.cardY
        )
        .padding(.horizontal, NommieTheme.Padding.medium)
    }
}

// MARK: - Macro Pill
struct MacroPill: View {
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
