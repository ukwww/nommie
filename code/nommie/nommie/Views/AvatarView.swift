import SwiftUI

// The one avatar component, used everywhere a user appears: profile headers,
// search rows, feed cards, follower lists, comments. Shows the profile photo
// when one exists; otherwise the user's first initial on their palette color —
// the same stable per-user color their recipe cards get.
struct AvatarView: View {
    let userId: String
    let username: String
    var photoURL: String? = nil
    var size: CGFloat = 40

    private var palette: CardPalette { CardPalettes.paletteForUser(userId) }

    var body: some View {
        Group {
            if let photoURL, !photoURL.isEmpty, let url = URL(string: photoURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialCircle
                }
            } else {
                initialCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialCircle: some View {
        ZStack {
            Circle().fill(palette.accent.opacity(0.15))
            Text(String(username.prefix(1)).uppercased())
                .font(Font.custom("Nunito-Bold", size: size * 0.42))
                .foregroundColor(palette.accent)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        AvatarView(userId: "abc123", username: "sam", size: 56)
        AvatarView(userId: "def456", username: "tomcooks", size: 40)
        AvatarView(userId: "ghi789", username: "ubin", size: 28)
    }
    .padding()
    .background(Color.nommieBackground)
}
