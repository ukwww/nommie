import SwiftUI

// Shown once, after a user's first-ever plate: a two-page celebration that
// guides them from the plate to sharing it. Paged (not auto-advancing) so the
// illustrations can't be skipped past before they're seen.
struct FirstPlateFlowView: View {
    let onExport: () -> Void
    let onSkip: () -> Void

    // A clean, consistent example dish for the mockup cards.
    private let exampleDish = "Chicken Udon"

    @State private var page = 0
    @State private var confettiDrop = false

    private let confetti: [(x: CGFloat, color: Color, size: CGFloat, delay: Double, spin: Double)] = {
        let colors = CardPalettes.others.map { $0.accent }
        return (0..<20).map { i in
            (x: CGFloat.random(in: 0.05...0.95),
             color: colors[i % colors.count],
             size: CGFloat.random(in: 6...11),
             delay: Double.random(in: 0...0.5),
             spin: Double.random(in: -180...180))
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.nommieBackground.ignoresSafeArea()

                // Confetti burst (celebration page)
                ForEach(Array(confetti.enumerated()), id: \.offset) { _, piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color.opacity(0.85))
                        .frame(width: piece.size, height: piece.size * 1.6)
                        .rotationEffect(.degrees(confettiDrop ? piece.spin : 0))
                        .position(x: geo.size.width * piece.x, y: confettiDrop ? geo.size.height * 0.55 : -40)
                        .opacity(confettiDrop ? 0 : 1)
                        .animation(.easeIn(duration: 1.7).delay(piece.delay), value: confettiDrop)
                }
                .opacity(page == 0 ? 1 : 0)

                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        celebrationPage.tag(0)
                        sharePage.tag(1)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut, value: page)

                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? Color.nommieGreen : Color.nommieBrown.opacity(0.2))
                                .frame(width: i == page ? 20 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: page)
                        }
                    }
                    .padding(.bottom, 24)

                    Button(action: {
                        if page == 0 { withAnimation { page = 1 } } else { onExport() }
                    }) {
                        HStack(spacing: 8) {
                            if page == 1 {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text(page == 0 ? "Next" : "Export my card")
                                .font(Font.custom("Nunito-SemiBold", size: 17))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.nommieGreen))
                    }
                    .padding(.horizontal, 28)

                    Button(action: onSkip) {
                        Text("Maybe later")
                            .font(Font.custom("Nunito-SemiBold", size: 14))
                            .foregroundColor(.nommieBrown.opacity(0.45))
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 44)
                }
            }
            .onAppear { withAnimation { confettiDrop = true } }
        }
    }

    // MARK: Page 1 — celebration + plate → export

    private var celebrationPage: some View {
        VStack(spacing: 0) {
            Spacer()
            PlateExportIllustration()
                .frame(height: 200)
            Spacer().frame(height: 40)
            Text("Congrats on your\nfirst plate!")
                .font(Font.custom("Lora-Bold", size: 30))
                .foregroundColor(.nommieBrown)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text("You made it. Now let's get it out into the world.")
                .font(Font.custom("Nunito-Regular", size: 15))
                .foregroundColor(.nommieBrown.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: Page 2 — two ways to share

    private var sharePage: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Two ways to share it")
                .font(Font.custom("Lora-Bold", size: 27))
                .foregroundColor(.nommieBrown)
            Text("Post it for everyone, or send it to a friend.")
                .font(Font.custom("Nunito-Regular", size: 15))
                .foregroundColor(.nommieBrown.opacity(0.55))
                .padding(.top, 8)
            Spacer().frame(height: 28)
            SharePathsIllustration(dish: exampleDish)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Shared mini card

private struct FPMiniCard: View {
    var palette: CardPalette = CardPalettes.neutral
    var width: CGFloat = 116
    var dish: String = "Chicken Udon"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Plated by: @you")
                .font(Font.custom("Caveat-Regular", size: 10))
                .foregroundColor(palette.accent)
                .padding(.horizontal, 8)
                .padding(.top, 7)
                .padding(.bottom, 4)

            RoundedRectangle(cornerRadius: 6)
                .fill(palette.accent.opacity(0.16))
                .frame(height: width * 0.5)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: width * 0.13))
                        .foregroundColor(palette.accent.opacity(0.45))
                )
                .padding(.horizontal, 8)

            Text(dish)
                .font(Font.custom("Lora-Bold", size: 10))
                .foregroundColor(.nommieBrown)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.top, 5)
                .padding(.bottom, 8)
        }
        .frame(width: width)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3])))
    }
}

// MARK: - Page 1 illustration: plate → export

private struct PlateExportIllustration: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Plate of food
            VStack(spacing: 10) {
                ZStack {
                    // steam
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(Color.nommieBrown.opacity(0.14))
                            .frame(width: 3, height: 16)
                            .offset(x: CGFloat(i - 1) * 13, y: -50)
                    }
                    Circle().stroke(Color.nommieBrown.opacity(0.35), lineWidth: 2).frame(width: 104, height: 104)
                    Circle().stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1).frame(width: 76, height: 76)
                    Capsule().fill(Color(hex: "D85A30").opacity(0.8)).frame(width: 34, height: 18).offset(x: -12, y: -4)
                    Circle().fill(Color(hex: "4A6741").opacity(0.8)).frame(width: 22, height: 22).offset(x: 14, y: -9)
                    Ellipse().fill(Color(hex: "E8C4A0")).frame(width: 28, height: 16).offset(x: 2, y: 13)
                }
                .frame(width: 120, height: 120)

                Text("Plate it")
                    .font(Font.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(.nommieBrown.opacity(0.7))
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.nommieBrown.opacity(0.3))

            // Card with export badge
            VStack(spacing: 10) {
                FPMiniCard(width: 120)
                    .overlay(alignment: .topTrailing) {
                        ZStack {
                            Circle().fill(Color.nommieGreen).frame(width: 30, height: 30)
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 9, y: -9)
                    }

                Text("Export the card")
                    .font(Font.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(.nommieBrown.opacity(0.7))
            }
        }
    }
}

// MARK: - Page 2 illustration: post it / send it

private struct SharePathsIllustration: View {
    let dish: String

    var body: some View {
        VStack(spacing: 16) {
            // Path 1 — post it to a platform
            VStack(spacing: 10) {
                phonePost
                Text("Post it")
                    .font(Font.custom("Nunito-Bold", size: 14))
                    .foregroundColor(.nommieBrown)
                Text("Share your card on Instagram, TikTok, anywhere")
                    .font(Font.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Rectangle().fill(Color.nommieBrown.opacity(0.12)).frame(height: 1)
                Text("or")
                    .font(Font.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(.nommieBrown.opacity(0.4))
                Rectangle().fill(Color.nommieBrown.opacity(0.12)).frame(height: 1)
            }
            .padding(.horizontal, 40)

            // Path 2 — send it to a friend who asks
            VStack(spacing: 10) {
                chat
                Text("Send it")
                    .font(Font.custom("Nunito-Bold", size: 14))
                    .foregroundColor(.nommieBrown)
                Text("A friend asks? Just send them the card")
                    .font(Font.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.nommieBrown.opacity(0.5))
            }
        }
    }

    // A phone showing your card posted, with likes.
    private var phonePost: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .frame(width: 90, height: 150)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.nommieBrown.opacity(0.25), lineWidth: 2))
            .overlay(
                VStack(spacing: 6) {
                    Capsule().fill(Color.nommieBrown.opacity(0.15)).frame(width: 26, height: 3).padding(.top, 8)
                    FPMiniCard(width: 70, dish: dish)
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.nommieBlush)
                        Text("128")
                            .font(Font.custom("Nunito-SemiBold", size: 10))
                            .foregroundColor(.nommieBrown.opacity(0.55))
                        Image(systemName: "bubble.right")
                            .font(.system(size: 10))
                            .foregroundColor(.nommieBrown.opacity(0.4))
                    }
                }
            )
    }

    // A friend asking, and your reply being the card.
    private var chat: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Can I get your \(dish) recipe?")
                    .font(Font.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.nommieBrown.opacity(0.8))
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14).fill(Color.nommieBrown.opacity(0.08))
                    )
                Spacer(minLength: 40)
            }

            HStack {
                Spacer(minLength: 40)
                FPMiniCard(palette: CardPalettes.neutral, width: 90, dish: dish)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.nommieGreen.opacity(0.12)))
            }
        }
        .frame(maxWidth: 260)
    }
}
