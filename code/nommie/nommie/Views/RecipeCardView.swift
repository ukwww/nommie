import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe
    var compact: Bool = false
    var thumbnail: Bool = false
    var currentUserId: String? = nil
    var likedByMe: Bool = false
    var followingIds: Set<String> = []
    var blockedIds: Set<String> = []
    var authorPhotoURL: String? = nil
    var onUsernameTap: (() -> Void)? = nil
    var onLikeTap: (() -> Void)? = nil
    var onLikerTap: ((String) -> Void)? = nil
    var onCommentTap: (() -> Void)? = nil
    var onDoubleTapLike: (() -> Void)? = nil

    @State private var likeBurst = false

    private var palette: CardPalette {
        CardPalettes.palette(forOwner: recipe.userId, currentUserId: currentUserId)
    }

    // The liker shown by name — prefer someone the viewer follows (or the
    // viewer themself), fall back to whoever liked first.
    private var pickedLiker: RecipeLiker? {
        guard recipe.likeCount > 0 else { return nil }
        return recipe.recentLikers.first {
            followingIds.contains($0.userId) || $0.userId == currentUserId
        } ?? recipe.recentLikers.first
    }

    // Newest-first from the trigger; show them oldest-first like a mini thread,
    // with blocked users' comments filtered out.
    private var previewComments: [RecipePreviewComment] {
        Array(recipe.recentComments
            .filter { !blockedIds.contains($0.userId) }
            .reversed())
    }

    // "@sam and 3 others liked"
    private var likerLine: String? {
        guard recipe.likeCount > 0 else { return nil }
        guard let picked = pickedLiker else {
            return recipe.likeCount == 1 ? "1 like" : "\(recipe.likeCount) likes"
        }
        let name = picked.userId == currentUserId ? "You" : "@\(picked.username)"
        let others = recipe.likeCount - 1
        if others <= 0 { return "\(name) liked this" }
        return "\(name) and \(others) \(others == 1 ? "other" : "others") liked"
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
        // Replate badge, top-left
        .overlay(alignment: .topLeading) {
            if recipe.isReplate {
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(palette.accent))
                    .padding(8)
            }
        }
        // Like heart + count, top-right
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
                if recipe.likeCount > 0 {
                    Text("\(recipe.likeCount)")
                        .font(Font.custom("Nunito-Bold", size: 19))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
                }
            }
            .padding(10)
        }
    }

    // MARK: - Full Card (Feed)
    var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header — avatar + replate or regular plated-by
            HStack(alignment: .center, spacing: 9) {
                Button(action: { onUsernameTap?() }) {
                    AvatarView(
                        userId: recipe.userId,
                        username: recipe.username,
                        photoURL: authorPhotoURL,
                        size: 30
                    )
                }
                .buttonStyle(PlainButtonStyle())

                if let meta = recipe.replateMeta {
                    VStack(alignment: .leading, spacing: 0) {
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
                } else {
                    Button(action: { onUsernameTap?() }) {
                        Text("Plated by: @\(recipe.username)")
                            .font(Font.custom("Caveat-Regular", size: 18))
                            .foregroundColor(palette.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer(minLength: 0)

                // Replate + save counts live up here, out of the social row's way
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 12))
                        if recipe.replateCount > 0 {
                            Text("\(recipe.replateCount)")
                                .font(Font.custom("Nunito-SemiBold", size: 12))
                        }
                    }
                    HStack(spacing: 3) {
                        Image(systemName: recipe.saveCount > 0 ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12))
                        if recipe.saveCount > 0 {
                            Text("\(recipe.saveCount)")
                                .font(Font.custom("Nunito-SemiBold", size: 12))
                        }
                    }
                }
                .foregroundColor(.nommieBrown.opacity(0.45))
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

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

            // Social block: liker line on top (full width), then the big
            // like + comment row, then up to two comment previews.
            VStack(alignment: .leading, spacing: 8) {
                if let line = likerLine {
                    Button(action: {
                        if let picked = pickedLiker, picked.userId != currentUserId {
                            onLikerTap?(picked.username)
                        }
                    }) {
                        Text(line)
                            .font(Font.custom("Nunito-SemiBold", size: 12.5))
                            .foregroundColor(.nommieBrown.opacity(0.6))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                HStack(spacing: 20) {
                    Button(action: { onLikeTap?() }) {
                        HStack(spacing: 6) {
                            Image(systemName: likedByMe ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundColor(likedByMe ? palette.accent : .nommieBrown.opacity(0.65))
                                .scaleEffect(likedByMe ? 1.0 : 0.96)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: likedByMe)
                            if recipe.likeCount > 0 {
                                Text("\(recipe.likeCount)")
                                    .font(Font.custom("Nunito-Bold", size: 15))
                                    .foregroundColor(.nommieBrown.opacity(0.75))
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { onCommentTap?() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 20))
                                .foregroundColor(.nommieBrown.opacity(0.65))
                            if recipe.commentCount > 0 {
                                Text("\(recipe.commentCount)")
                                    .font(Font.custom("Nunito-Bold", size: 15))
                                    .foregroundColor(.nommieBrown.opacity(0.75))
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Text("nommie")
                        .font(Font.custom("Nunito-Regular", size: 11))
                        .italic()
                        .foregroundColor(.nommieBrown.opacity(0.3))
                }

                let previews = previewComments
                if !previews.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(previews, id: \.self) { comment in
                            Button(action: { onCommentTap?() }) {
                                (Text("@\(comment.username) ")
                                    .font(Font.custom("Nunito-Bold", size: 12.5))
                                 + Text(comment.text)
                                    .font(Font.custom("Nunito-Regular", size: 12.5)))
                                    .foregroundColor(.nommieBrown.opacity(0.75))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if recipe.commentCount > previews.count {
                            Button(action: { onCommentTap?() }) {
                                Text("View all \(recipe.commentCount) comments")
                                    .font(Font.custom("Nunito-Regular", size: 12))
                                    .foregroundColor(.nommieBrown.opacity(0.45))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
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
        .overlay {
            if likeBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 2)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .highPriorityGesture(TapGesture(count: 2).onEnded { doubleTapLike() })
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    private func doubleTapLike() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { likeBurst = true }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onDoubleTapLike?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) { likeBurst = false }
        }
    }
}

// MARK: - Prep Time Row (quarter-fill clock)
struct StarsRow: View {
    let stars: Int
    let accent: Color
    let timeLabel: String

    var body: some View {
        HStack(spacing: 5) {
            QuarterClockIcon(quarters: min(max(stars, 1), 4), size: 14, accent: accent)
            Text(timeLabel)
                .font(Font.custom("Nunito-Regular", size: 12))
                .foregroundColor(.nommieBrown.opacity(0.5))
        }
    }
}

// A single alarm-clock face that fills by quarters: 1/4 = ~15 min, 2/4 = ~30,
// 3/4 = ~45, full = ~60. Replaces the old star rating, which read as difficulty.
struct QuarterClockIcon: View {
    let quarters: Int      // 1...4
    let size: CGFloat
    let accent: Color

    var body: some View {
        ZStack {
            // Alarm bells
            Group {
                bellLine(angle: -45)
                bellLine(angle: 45)
            }

            // Face
            Circle()
                .stroke(accent, lineWidth: max(1.2, size * 0.09))

            // Quarter fill, from 12 o'clock
            PieSliceShape(fraction: Double(min(max(quarters, 0), 4)) / 4.0)
                .fill(accent.opacity(0.85))
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
    }

    private func bellLine(angle: Double) -> some View {
        Capsule()
            .fill(accent)
            .frame(width: max(1.4, size * 0.1), height: size * 0.24)
            .offset(y: -size * 0.56)
            .rotationEffect(.degrees(angle))
    }
}

struct PieSliceShape: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard fraction > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * min(fraction, 1.0)),
            clockwise: false
        )
        path.closeSubpath()
        return path
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
