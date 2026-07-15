import SwiftUI

// MARK: - Onboarding Container

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            illustration: .welcome,
            headline: "Welcome to nommie",
            subhead: "your personal cookbook",
            body: "Build your collection of recipe cards."
        ),
        OnboardingPage(
            illustration: .card,
            headline: "Cook it. Log it.\nIt's officially your creation."
        ),
        OnboardingPage(
            illustration: .replate,
            headline: "Found a recipe you love?\nReplate it.",
            body: "Put your own spin on it, your recipe referencing the original."
        ),
        OnboardingPage(
            illustration: .friends,
            headline: "See what your friends\nare cooking.",
            body: "Collect their recipes, remake their dishes, and stay connected through cooking."
        )
    ]

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Text("Skip")
                            .font(Font.custom("Nunito-SemiBold", size: 14))
                            .foregroundColor(.nommieBrown.opacity(0.4))
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 20)
                }

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.nommieGreen : Color.nommieBrown.opacity(0.2))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 28)

                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        isPresented = false
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Log your first plate")
                        .font(Font.custom("Nunito-SemiBold", size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.nommieGreen))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Page model

struct OnboardingPage {
    enum IllustrationType { case welcome, card, replate, friends }
    let illustration: IllustrationType
    let headline: String
    var subhead: String? = nil
    var body: String? = nil
}

// MARK: - Page view

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                switch page.illustration {
                case .welcome: OnboardingWelcomeIllustration()
                case .card:    OnboardingCardIllustration()
                case .replate: OnboardingReplateIllustration()
                case .friends: OnboardingFriendsIllustration()
                }
            }
            .frame(height: 270)
            .padding(.bottom, 38)

            VStack(spacing: 10) {
                Text(page.headline)
                    .font(Font.custom("Lora-Bold", size: 28))
                    .foregroundColor(.nommieBrown)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                if let subhead = page.subhead {
                    Text(subhead)
                        .font(Font.custom("Caveat-Bold", size: 24))
                        .foregroundColor(.nommieGreen)
                }

                if let body = page.body, !body.isEmpty {
                    Text(body)
                        .font(Font.custom("Nunito-Regular", size: 16))
                        .foregroundColor(.nommieBrown.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 32)
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Theme

private enum OBTheme {
    static let accent = Color(hex: "3A5C44")
    static let bg     = Color(hex: "EDE8DC")
}

// MARK: - Shared sub-views

private struct OBMacroCell: View {
    let value, label: String
    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(Font.custom("Nunito-Bold", size: 9)).foregroundColor(.nommieBrown)
            Text(label).font(Font.custom("Nunito-Regular", size: 6.5)).foregroundColor(.nommieBrown.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(OBTheme.accent.opacity(0.08))
        .overlay(Rectangle().stroke(OBTheme.accent.opacity(0.12), lineWidth: 0.5))
    }
}

private struct OBTag: View {
    let text: String
    var accent: Color = OBTheme.accent
    var body: some View {
        Text(text)
            .font(Font.custom("Nunito-Regular", size: 8))
            .foregroundColor(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(accent.opacity(0.12)))
    }
}

// A small colored recipe card used in the collage illustrations.
private struct OBMiniCard: View {
    let palette: CardPalette
    let dish: String
    var width: CGFloat = 100
    var handle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let handle {
                HStack(spacing: 4) {
                    Circle()
                        .fill(palette.accent.opacity(0.18))
                        .frame(width: 15, height: 15)
                        .overlay(
                            Text(String(handle.prefix(1)).uppercased())
                                .font(Font.custom("Nunito-Bold", size: 8))
                                .foregroundColor(palette.accent)
                        )
                    Text("@\(handle)")
                        .font(Font.custom("Caveat-Regular", size: 11))
                        .foregroundColor(palette.accent)
                }
                .padding(.horizontal, 7)
                .padding(.top, 7)
                .padding(.bottom, 4)
            }

            RoundedRectangle(cornerRadius: 6)
                .fill(palette.accent.opacity(0.16))
                .frame(height: 52)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14))
                        .foregroundColor(palette.accent.opacity(0.4))
                )
                .padding(.horizontal, 7)
                .padding(.top, handle == nil ? 7 : 0)

            Text(dish)
                .font(Font.custom("Lora-Bold", size: 9.5))
                .foregroundColor(.nommieBrown)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.top, 5)
                .padding(.bottom, 8)
        }
        .frame(width: width)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(palette.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
        )
        .shadow(color: .black.opacity(0.09), radius: 7, x: 0, y: 3)
    }
}

// MARK: - Screen 1: Welcome — a colorful scatter of recipe cards

struct OnboardingWelcomeIllustration: View {
    // Uses the app's real per-user palettes so the collage previews the
    // colors people's cards actually take.
    private var palettes: [CardPalette] { CardPalettes.others }

    var body: some View {
        ZStack {
            OBMiniCard(palette: palettes[5], dish: "Bibimbap", width: 96)
                .rotationEffect(.degrees(-15))
                .offset(x: -78, y: -52)
            OBMiniCard(palette: palettes[2], dish: "Spicy Rigatoni", width: 96)
                .rotationEffect(.degrees(13))
                .offset(x: 74, y: -58)
            OBMiniCard(palette: palettes[0], dish: "Miso Salmon", width: 96)
                .rotationEffect(.degrees(-8))
                .offset(x: -86, y: 44)
            OBMiniCard(palette: palettes[3], dish: "Taro Latte", width: 96)
                .rotationEffect(.degrees(9))
                .offset(x: 80, y: 40)
            OBMiniCard(palette: palettes[4], dish: "Chicken Juk", width: 100)
                .rotationEffect(.degrees(4))
                .offset(x: 22, y: 4)
            OBMiniCard(palette: palettes[1], dish: "Berry Pavlova", width: 100)
                .rotationEffect(.degrees(-4))
                .offset(x: -30, y: -2)
        }
    }
}

// MARK: - Screen 2: Card — shows what a nommie recipe card looks like

struct OnboardingCardIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.nommieBrown.opacity(0.05))
                .frame(width: 210, height: 218)
                .offset(x: 9, y: 10)

            VStack(alignment: .leading, spacing: 0) {
                Text("Plated by: @you")
                    .font(Font.custom("Caveat-Regular", size: 13))
                    .foregroundColor(OBTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                RoundedRectangle(cornerRadius: 8)
                    .fill(OBTheme.accent.opacity(0.09))
                    .frame(height: 86)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 22))
                            .foregroundColor(OBTheme.accent.opacity(0.35))
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                Text("Spicy Vodka Rigatoni")
                    .font(Font.custom("Lora-Bold", size: 13))
                    .foregroundColor(.nommieBrown)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 5)

                HStack(spacing: 3) {
                    QuarterClockIcon(quarters: 3, size: 10, accent: OBTheme.accent)
                    Text("~45 min")
                        .font(Font.custom("Nunito-Regular", size: 8))
                        .foregroundColor(.nommieBrown.opacity(0.45))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 7)

                HStack(spacing: 0) {
                    OBMacroCell(value: "580", label: "CAL")
                    OBMacroCell(value: "24g", label: "PRO")
                    OBMacroCell(value: "68g", label: "CARB")
                    OBMacroCell(value: "22g", label: "FAT")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                HStack {
                    HStack(spacing: 4) {
                        OBTag(text: "Italian")
                        OBTag(text: "Pasta")
                    }
                    Spacer()
                    Text("nommie")
                        .font(Font.custom("Nunito-Regular", size: 8))
                        .italic()
                        .foregroundColor(.nommieBrown.opacity(0.25))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .frame(width: 210)
            .background(OBTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(OBTheme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - Screen 3: Replate — the friend's original beside your replate

struct OnboardingReplateIllustration: View {
    private var theirs: CardPalette { CardPalettes.others[5] } // slate
    private var yours: CardPalette { CardPalettes.neutral }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            replateCard(palette: theirs, platedBy: "@marcus", dish: "Spicy Rigatoni", tag: "Pasta", isReplate: false)
                .rotationEffect(.degrees(-4))

            replateCard(palette: yours, platedBy: "@you", dish: "Vegan Rigatoni", tag: "Vegan", isReplate: true, origin: "marcus")
                .rotationEffect(.degrees(4))
        }
    }

    @ViewBuilder
    private func replateCard(palette: CardPalette, platedBy: String, dish: String, tag: String, isReplate: Bool, origin: String? = nil) -> some View {
        let w: CGFloat = 144
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(isReplate ? "Replated" : "Plated") by: \(platedBy)")
                    .font(Font.custom("Caveat-Regular", size: 10))
                    .foregroundColor(palette.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, origin == nil ? 5 : 1)

                if let origin {
                    Text("↻ from @\(origin)")
                        .font(Font.custom("Nunito-Regular", size: 7.5))
                        .foregroundColor(.nommieBrown.opacity(0.5))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 5)
                }

                RoundedRectangle(cornerRadius: 7)
                    .fill(palette.accent.opacity(0.12))
                    .frame(height: 76)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 16))
                            .foregroundColor(palette.accent.opacity(0.35))
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)

                Text(dish)
                    .font(Font.custom("Lora-Bold", size: 11))
                    .foregroundColor(.nommieBrown)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)

                HStack(spacing: 2) {
                    QuarterClockIcon(quarters: 3, size: 9, accent: palette.accent)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

                OBTag(text: tag, accent: palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
            }
            .frame(width: w)
            .background(palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .shadow(color: .black.opacity(isReplate ? 0.13 : 0.08), radius: isReplate ? 12 : 8, x: 0, y: isReplate ? 5 : 3)

            if isReplate {
                ZStack {
                    Circle()
                        .fill(Color.nommieGreen)
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .offset(x: 9, y: -9)
            }
        }
    }
}

// MARK: - Screen 4: Friends — collect your friends' cards

struct OnboardingFriendsIllustration: View {
    private var palettes: [CardPalette] { CardPalettes.others }

    var body: some View {
        ZStack {
            OBMiniCard(palette: palettes[5], dish: "Bibimbap", width: 128, handle: "marcus")
                .rotationEffect(.degrees(-11))
                .offset(x: -58, y: 10)

            OBMiniCard(palette: palettes[2], dish: "Matcha Cake", width: 128, handle: "lena")
                .rotationEffect(.degrees(11))
                .offset(x: 58, y: 6)

            OBMiniCard(palette: palettes[1], dish: "Miso Salmon", width: 138, handle: "sam")
                .rotationEffect(.degrees(0))
                .offset(x: 0, y: -14)
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color.nommieGreen)
                            .frame(width: 30, height: 30)
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: -22)
                }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
