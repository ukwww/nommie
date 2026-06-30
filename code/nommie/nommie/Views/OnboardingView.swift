import SwiftUI

// MARK: - Onboarding Container

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            illustration: .card,
            headline: "Cook it. Log it.\nIt's officially yours.",
            body: "Snap a photo, fill in the details, and nommie turns it into a recipe card with your name on it. Followed someone else's recipe or went completely off script, it counts all the same."
        ),
        OnboardingPage(
            illustration: .collection,
            headline: "Build your personal\ncollection.",
            body: "Every plate you log is yours, saved to your collection. Whether you are counting macros or someone who just loves to cook, think of it as your own personal cookbook."
        ),
        OnboardingPage(
            illustration: .replate,
            headline: "Found a recipe\nyou love? Make it yours.",
            body: "Cook it and log it as a replate. Follow the recipe to the letter or adjust it to your taste. Go vegan, swap the protein, dial in the portions. Once you cook it, it's yours."
        ),
        OnboardingPage(
            illustration: .discover,
            headline: "Follow the cooks\nyou love.",
            body: "Find anyone by their @username and browse what they've cooked.\n\nSee a card posted online, look up the handle. In person, the QR gets you there."
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
    enum IllustrationType { case card, collection, replate, discover }
    let illustration: IllustrationType
    let headline: String
    let body: String
}

// MARK: - Page view

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Group {
                switch page.illustration {
                case .card:       OnboardingCardIllustration()
                case .collection: OnboardingCollectionIllustration()
                case .replate:    OnboardingReplateIllustration()
                case .discover:   OnboardingDiscoverIllustration()
                }
            }
            .frame(height: 260)
            .padding(.bottom, 40)

            VStack(spacing: 14) {
                Text(page.headline)
                    .font(Font.custom("Lora-Bold", size: 28))
                    .foregroundColor(.nommieBrown)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(page.body)
                    .font(Font.custom("Nunito-Regular", size: 16))
                    .foregroundColor(.nommieBrown.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
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
    var body: some View {
        Text(text)
            .font(Font.custom("Nunito-Regular", size: 8))
            .foregroundColor(OBTheme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(OBTheme.accent.opacity(0.1)))
    }
}

// MARK: - Screen 1: Card — shows what a nommie recipe card looks like

struct OnboardingCardIllustration: View {
    var body: some View {
        ZStack {
            // Drop shadow
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
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= 3 ? "star.fill" : "star")
                            .font(.system(size: 8))
                            .foregroundColor(i <= 3 ? Color(hex: "E0A930") : OBTheme.accent.opacity(0.2))
                    }
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

// MARK: - Screen 2: Collection — fan of cards

struct OnboardingCollectionIllustration: View {
    var body: some View {
        ZStack {
            collectionCard(dish: "Miso Salmon", cal: "390", tag: "High Protein")
                .rotationEffect(.degrees(-16))
                .offset(x: -72, y: 22)

            collectionCard(dish: "Avocado Toast", cal: "310", tag: "Plant-Based")
                .rotationEffect(.degrees(-5))
                .offset(x: -16, y: 6)

            collectionCard(dish: "Spicy Rigatoni", cal: "580", tag: "Pasta")
                .rotationEffect(.degrees(7))
                .offset(x: 46, y: -10)
        }
    }

    @ViewBuilder
    private func collectionCard(dish: String, cal: String, tag: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Plated by: @you")
                .font(Font.custom("Caveat-Regular", size: 11))
                .foregroundColor(OBTheme.accent)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 5)

            RoundedRectangle(cornerRadius: 7)
                .fill(OBTheme.accent.opacity(0.09))
                .frame(height: 78)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18))
                        .foregroundColor(OBTheme.accent.opacity(0.3))
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            Text(dish)
                .font(Font.custom("Lora-Bold", size: 11))
                .foregroundColor(.nommieBrown)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.bottom, 5)

            // Calorie pill
            Text(cal + " cal")
                .font(Font.custom("Nunito-SemiBold", size: 9))
                .foregroundColor(OBTheme.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(OBTheme.accent.opacity(0.1)))
                .padding(.horizontal, 10)
                .padding(.bottom, 5)

            OBTag(text: tag)
                .padding(.horizontal, 10)
                .padding(.bottom, 9)
        }
        .frame(width: 138)
        .background(OBTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(OBTheme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 3)
    }
}

// MARK: - Screen 3: Replate — two cards, right card has replate badge

struct OnboardingReplateIllustration: View {
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            replateCard(platedBy: "@marcus", dish: "Spicy Rigatoni", tag: "Pasta", hasBadge: false, isReplate: false)
                .rotationEffect(.degrees(-4))

            replateCard(platedBy: "@you", dish: "Vegan Rigatoni", tag: "Vegan", hasBadge: true, isReplate: true)
                .rotationEffect(.degrees(4))
        }
    }

    @ViewBuilder
    private func replateCard(platedBy: String, dish: String, tag: String, hasBadge: Bool, isReplate: Bool) -> some View {
        let w: CGFloat = 144
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(isReplate ? "Replated" : "Plated") by: \(platedBy)")
                    .font(Font.custom("Caveat-Regular", size: 10))
                    .foregroundColor(OBTheme.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 5)

                RoundedRectangle(cornerRadius: 7)
                    .fill(OBTheme.accent.opacity(0.09))
                    .frame(height: 76)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 16))
                            .foregroundColor(OBTheme.accent.opacity(0.3))
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
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= 3 ? "star.fill" : "star")
                            .font(.system(size: 7))
                            .foregroundColor(i <= 3 ? Color(hex: "E0A930") : OBTheme.accent.opacity(0.2))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

                OBTag(text: tag)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
            }
            .frame(width: w)
            .background(OBTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(OBTheme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .shadow(color: .black.opacity(hasBadge ? 0.13 : 0.08), radius: hasBadge ? 12 : 8, x: 0, y: hasBadge ? 5 : 3)

            if hasBadge {
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

// MARK: - Screen 4: Discover — username search + QR in-person hint

struct OnboardingDiscoverIllustration: View {
    var body: some View {
        VStack(spacing: 10) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.nommieBrown.opacity(0.4))
                Text("@marcus")
                    .font(Font.custom("Nunito-Regular", size: 14))
                    .foregroundColor(.nommieBrown)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.nommieGreen.opacity(0.45), lineWidth: 1)
            )
            .frame(width: 250)

            // Profile result
            HStack(spacing: 10) {
                Circle()
                    .fill(OBTheme.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("M")
                            .font(Font.custom("Lora-Bold", size: 15))
                            .foregroundColor(OBTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("@marcus")
                        .font(Font.custom("Nunito-Bold", size: 13))
                        .foregroundColor(.nommieBrown)
                    Text("14 plates")
                        .font(Font.custom("Nunito-Regular", size: 10))
                        .foregroundColor(.nommieBrown.opacity(0.45))
                }

                Spacer()

                Text("Follow")
                    .font(Font.custom("Nunito-SemiBold", size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.nommieGreen))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 250)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.nommieBrown.opacity(0.08), lineWidth: 1)
            )

            // Mini plates from their profile
            HStack(spacing: 8) {
                ForEach(["Miso Salmon", "Bibimbap"], id: \.self) { dish in
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(OBTheme.accent.opacity(0.09))
                            .frame(height: 46)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 11))
                                    .foregroundColor(OBTheme.accent.opacity(0.3))
                            )
                        Text(dish)
                            .font(Font.custom("Lora-Bold", size: 9))
                            .foregroundColor(.nommieBrown)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                    }
                    .frame(maxWidth: .infinity)
                    .background(OBTheme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(OBTheme.accent.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
                }
            }
            .frame(width: 250)

            // QR in-person callout
            HStack(spacing: 7) {
                Image(systemName: "qrcode")
                    .font(.system(size: 12))
                    .foregroundColor(OBTheme.accent.opacity(0.55))
                Text("or scan the QR on their card to share in person")
                    .font(Font.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.nommieBrown.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 250)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.nommieBrown.opacity(0.07), lineWidth: 1)
            )
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
