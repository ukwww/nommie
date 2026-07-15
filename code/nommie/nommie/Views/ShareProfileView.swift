import SwiftUI

// The "invite a friend" card: a recipe-card-styled artifact of your profile —
// avatar, @username, a QR that links to your profile, and the date you joined.
// Exports as an image to send; scanning the QR takes them straight to you.
struct ShareProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var showSuccess = false

    private var user: NommieUser? { authViewModel.currentNommieUser }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Share your nommie")
                    .font(Font.custom("Lora-SemiBold", size: 20))
                    .foregroundColor(.nommieBrown)
                    .padding(.top, 24)
                    .padding(.bottom, 6)

                Text("Send this card to a friend. They scan it to find you.")
                    .font(Font.custom("Nunito-Regular", size: 13))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 28)

                if let user {
                    ProfileShareCard(
                        username: user.username,
                        userId: user.id,
                        photoURL: user.photoURL,
                        createdAt: user.createdAt
                    )
                }

                Spacer()

                Button(action: shareCard) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Share card")
                            .font(Font.custom("Nunito-SemiBold", size: 16))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.nommieGreen))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .frame(width: 30, height: 30)
                    .background(Circle().strokeBorder(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .presentationDetents([.large])
    }

    @MainActor
    private func shareCard() {
        guard let user else { return }
        let card = ProfileShareCard(
            username: user.username, userId: user.id,
            photoURL: user.photoURL, createdAt: user.createdAt
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = windowScene.windows.first?.rootViewController {
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            vc.present(activityVC, animated: true)
        }
    }
}

// The card artifact itself — rendered on screen and exported as an image.
struct ProfileShareCard: View {
    let username: String
    let userId: String
    let photoURL: String?
    let createdAt: Date

    private let accent = Color.nommieGreen
    private var joinedLabel: String {
        "Plated on: \(createdAt.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(joinedLabel)
                .font(Font.custom("Caveat-Regular", size: 16))
                .foregroundColor(accent)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            VStack(spacing: 14) {
                AvatarView(userId: userId, username: username, photoURL: photoURL, size: 72)

                Text("@\(username)")
                    .font(Font.custom("Lora-Bold", size: 24))
                    .foregroundColor(.nommieBrown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                CardQRCode(value: "https://getnommie.app/@\(username)", size: 128, accent: accent)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))

                Text("Scan to see my plates")
                    .font(Font.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.nommieBrown.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .padding(.horizontal, 16)

            HStack {
                Spacer()
                Text("nommie")
                    .font(Font.custom("Caveat-Bold", size: 18))
                    .foregroundColor(accent.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: 300)
        .background(Color(hex: "EDE8DC"))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }
}
