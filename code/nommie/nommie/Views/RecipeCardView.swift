import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe
    var compact: Bool = false
    var thumbnail: Bool = false
    var currentUserId: String? = nil
    var onUsernameTap: (() -> Void)? = nil

    private var palette: CardPalette {
        CardPalettes.palette(forOwner: recipe.userId, currentUserId: currentUserId)
    }

    var body: some View {
        if thumbnail {
            thumbnailCard
        } else {
            fullCard
        }
    }

    // MARK: - Thumbnail Card (Profile Grid) — image with overlaid name
    var thumbnailCard: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geo in
                    CachedAsyncImage(url: URL(string: recipe.imageURL)) { image in
                        image.resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(palette.accent.opacity(0.1))
                            .frame(width: geo.size.width, height: geo.size.width)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .foregroundColor(palette.accent.opacity(0.3))
                            )
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)

                // Bottom scrim + dish name
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.55)],
                    startPoint: .center, endPoint: .bottom
                )
                .allowsHitTesting(false)

                Text(recipe.dishName)
                    .font(Font.custom("Lora-Bold", size: 15))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )

            // Replate badge
            if recipe.isReplate {
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(palette.accent))
                    .padding(8)
            }
        }
    }

    // MARK: - Full Card (Feed)
    var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header — replate or regular plated-by
            if let meta = recipe.replateMeta {
                VStack(alignment: .leading, spacing: 2) {
                    Button(action: { onUsernameTap?() }) {
                        Text("Replated by: @\(recipe.username)")
                            .font(Font.custom("Caveat-Regular", size: 18))
                            .foregroundColor(palette.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Text("↻ from @\(meta.originalUsername)")
                        .font(Font.custom("Nunito-Regular", size: 12))
                        .foregroundColor(palette.accent.opacity(0.7))
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)
            } else {
                Button(action: { onUsernameTap?() }) {
                    Text("Plated by: @\(recipe.username)")
                        .font(Font.custom("Caveat-Regular", size: 18))
                        .foregroundColor(palette.accent)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            // Horizontal row: image left, content right
            HStack(alignment: .top, spacing: 14) {
                CachedAsyncImage(url: URL(string: recipe.imageURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(palette.accent.opacity(0.1))
                        .overlay(
                            Image(systemName: "fork.knife")
                                .foregroundColor(palette.accent.opacity(0.3))
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.dishName)
                        .font(Font.custom("Lora-Bold", size: 18))
                        .foregroundColor(.nommieBrown)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    StarsRow(stars: recipe.prepTimeStars, accent: palette.accent, timeLabel: recipe.prepTimeLabel)

                    HStack(spacing: 0) {
                        FeedMacroCol(value: "\(recipe.macros.calories)", label: "CAL")
                        FeedMacroCol(value: "\(recipe.macros.protein)g", label: "PRO")
                        FeedMacroCol(value: "\(recipe.macros.carbs)g", label: "CARB")
                        FeedMacroCol(value: "\(recipe.macros.fat)g", label: "FAT")
                        FeedMacroCol(value: "\(recipe.macros.fiber)g", label: "FIB")
                        FeedMacroCol(value: "\(recipe.macros.sugar)g", label: "SUG")
                    }

                    if !recipe.tags.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(recipe.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(Font.custom("Nunito-Regular", size: 11))
                                    .foregroundColor(palette.accent)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(palette.accent.opacity(0.12)))
                            }
                            if recipe.tags.count > 2 {
                                Text("+\(recipe.tags.count - 2)")
                                    .font(Font.custom("Nunito-Regular", size: 11))
                                    .foregroundColor(.nommieBrown.opacity(0.45))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)

            HStack {
                Spacer()
                Text("nommie")
                    .font(Font.custom("Nunito-Regular", size: 11))
                    .italic()
                    .foregroundColor(.nommieBrown.opacity(0.3))
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 16)
    }
}

// MARK: - Stars Row (prep time)
struct StarsRow: View {
    let stars: Int
    let accent: Color
    let timeLabel: String

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= stars ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundColor(i <= stars ? Color(hex: "E0A930") : .nommieBrown.opacity(0.25))
                }
            }
            Text(timeLabel)
                .font(Font.custom("Nunito-Regular", size: 12))
                .foregroundColor(.nommieBrown.opacity(0.5))
        }
    }
}

// MARK: - Feed Macro Column
struct FeedMacroCol: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Font.custom("Nunito-Bold", size: 12))
                .foregroundColor(.nommieBrown)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(Font.custom("Nunito-Regular", size: 9))
                .foregroundColor(.nommieBrown.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - MacroPill (kept for export views)
struct MacroPill: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Font.custom("Nunito-Bold", size: 15))
                .foregroundColor(.nommieBrown)
            Text(label)
                .font(Font.custom("Nunito-Regular", size: 10))
                .foregroundColor(.nommieBrown.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(accent.opacity(0.07))
        .overlay(Rectangle().stroke(accent.opacity(0.1), lineWidth: 0.5))
    }
}
