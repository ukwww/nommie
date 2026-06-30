import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeFeedViewModel()
    @State private var showingRecipeCreation = false
    @State private var showingUserSearch = false
    @State private var selectedRecipe: Recipe? = nil
    @State private var replateSource: Recipe? = nil
    @State private var selectedUsername: String? = nil
    private var currentUserId: String? { authViewModel.currentNommieUser?.id }

    var body: some View {
        ZStack(alignment: .top) {
            Color.nommieBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Feed content
                    if viewModel.isLoading {
                        VStack(spacing: 0) {
                            GhostFeedCard()
                            GhostFeedCard().padding(.top, 18).opacity(0.6)
                            NommieSpinningLogo(size: 32).padding(.top, 28)
                        }
                        .padding(.top, 8)
                    } else if viewModel.filteredRecipes.isEmpty {
                        if viewModel.selectedTag != nil {
                            // Tag filter produced no results — simple inline message
                            VStack(spacing: 8) {
                                Text("No \(viewModel.selectedTag!) plates yet")
                                    .font(Font.custom("Lora-Bold", size: 18))
                                    .foregroundColor(.nommieBrown)
                                Text("Try a different filter")
                                    .font(Font.custom("Nunito-Regular", size: 14))
                                    .foregroundColor(.nommieBrown.opacity(0.5))
                            }
                            .padding(.top, 60)
                        } else {
                            // True empty feed: ghost → message+CTA → ghost
                            VStack(spacing: 0) {
                                GhostFeedCard()

                                FeedEmptyState(
                                    onFindFriends: { showingUserSearch = true },
                                    onLogPlate: { showingRecipeCreation = true }
                                )
                                .padding(.vertical, 28)
                                .padding(.horizontal, 4)

                                GhostFeedCard().opacity(0.35)
                            }
                        }
                    } else {
                        LazyVStack(spacing: 18) {
                            ForEach(viewModel.filteredRecipes) { recipe in
                                Button(action: { selectedRecipe = recipe }) {
                                    RecipeCardView(
                                        recipe: recipe,
                                        compact: true,
                                        currentUserId: currentUserId,
                                        onUsernameTap: {
                                            if recipe.userId != currentUserId {
                                                selectedUsername = recipe.username
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.bottom, 110)
                    }
                }
                .padding(.top, 80)
            }

            // Sticky header
            HStack(alignment: .center) {
                Text("nommie ")
                    .font(Font.custom("Caveat-Bold", size: 36))
                    .foregroundColor(.nommieGreen)
                Spacer()
                if let username = authViewModel.currentNommieUser?.username {
                    Text("@\(username)")
                        .font(Font.custom("Nunito-Regular", size: 14))
                        .foregroundColor(.nommieBrown.opacity(0.55))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(Color.nommieBackground)

        }
        .sheet(isPresented: $showingUserSearch) {
            UserSearchView().environmentObject(authViewModel)
        }
        .sheet(item: $selectedRecipe) { recipe in
            let isOwner = recipe.userId == currentUserId
            RecipeDetailView(
                recipe: recipe,
                isOwner: isOwner,
                onDelete: { viewModel.removeRecipe(id: recipe.id) },
                onReplate: { source in replateSource = source }
            )
            .environmentObject(authViewModel)
        }
        .sheet(item: Binding(
            get: { selectedUsername.map { IdentifiableString(value: $0) } },
            set: { selectedUsername = $0?.value }
        )) { wrapper in
            OtherUserProfileView(username: wrapper.value)
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showingRecipeCreation) {
            RecipeCreationView(isPresented: $showingRecipeCreation)
                .environmentObject(authViewModel)
        }
        .fullScreenCover(item: $replateSource, onDismiss: {
            Task { await viewModel.fetchAllRecipes(currentUserId: currentUserId) }
        }) { source in
            RecipeCreationView(isPresented: Binding(
                get: { replateSource != nil },
                set: { if !$0 { replateSource = nil } }
            ), replateSource: source)
            .environmentObject(authViewModel)
        }
        .onAppear {
            Task { await viewModel.fetchAllRecipes(currentUserId: currentUserId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRecipeCreation)) { _ in
            showingRecipeCreation = true
        }
        .onChange(of: showingRecipeCreation) {
            if !showingRecipeCreation {
                Task { await viewModel.fetchAllRecipes(currentUserId: currentUserId) }
            }
        }
    }
}

// MARK: - Weekly Overview Banner
struct WeeklyOverviewBanner: View {
    let plates: Int
    let avgProtein: Int
    @Binding var expanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                HStack(spacing: 0) {
                    // Left column: plates count
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(plates)")
                            .font(Font.custom("Nunito-Bold", size: 20))
                            .foregroundColor(.nommieYellow)
                        Text(plates == 1 ? "plate this week" : "plates this week")
                            .font(Font.custom("Nunito-SemiBold", size: 14))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if avgProtein > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 1, height: 30)
                            .padding(.horizontal, 14)

                        // Right column: avg protein
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(avgProtein)g")
                                .font(Font.custom("Nunito-Bold", size: 20))
                                .foregroundColor(.nommieYellow)
                            Text("avg protein")
                                .font(Font.custom("Nunito-SemiBold", size: 14))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.leading, 10)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(Color.white.opacity(0.2))
                    if plates == 0 {
                        Text("You haven't plated anything this week yet. Tap + to start your streak.")
                            .font(Font.custom("Nunito-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.85))
                    } else {
                        Text("Nutritional highlight")
                            .font(Font.custom("Nunito-SemiBold", size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Averaging \(avgProtein)g of protein across \(plates) \(plates == 1 ? "plate" : "plates") — keep it up!")
                            .font(Font.custom("Nunito-Regular", size: 14))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .background(Color.nommieGreen)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Font.custom("Nunito-SemiBold", size: 14))
                .foregroundColor(isSelected ? .white : .nommieGreen)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? Color.nommieGreen : Color.clear)
                )
                .overlay(
                    Capsule().stroke(Color.nommieGreen.opacity(isSelected ? 0 : 0.5), lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Ghost Feed Card (skeleton placeholder, non-interactive)
struct GhostFeedCard: View {
    private let bg = Color(hex: "EDE8DC")
    private let block = Color.nommieBrown.opacity(0.09)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "Plated by" placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(block)
                .frame(width: 130, height: 13)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 14) {
                // Image placeholder
                RoundedRectangle(cornerRadius: 14)
                    .fill(block)
                    .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 9) {
                    // Dish name
                    RoundedRectangle(cornerRadius: 4).fill(block).frame(maxWidth: .infinity).frame(height: 15)
                    RoundedRectangle(cornerRadius: 4).fill(block).frame(width: 90, height: 15)
                    // Stars
                    RoundedRectangle(cornerRadius: 4).fill(block).frame(width: 110, height: 11)
                    // Macros
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { _ in
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 3).fill(block).frame(height: 13)
                                RoundedRectangle(cornerRadius: 3).fill(block).frame(height: 9)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    // Tags
                    HStack(spacing: 6) {
                        Capsule().fill(block).frame(width: 68, height: 20)
                        Capsule().fill(block).frame(width: 52, height: 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)

            HStack { Spacer(); RoundedRectangle(cornerRadius: 3).fill(block).frame(width: 42, height: 9) }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.nommieBrown.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }
}

// MARK: - Feed Empty State CTA
struct FeedEmptyState: View {
    let onFindFriends: () -> Void
    let onLogPlate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("See what others are plating")
                .font(Font.custom("Lora-Bold", size: 22))
                .foregroundColor(.nommieBrown)
            Text("Follow friends to see their recipe cards here.\nOr log your own — then export and post the card.")
                .font(Font.custom("Nunito-Regular", size: 15))
                .foregroundColor(.nommieBrown.opacity(0.55))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(action: onFindFriends) {
                    Text("Find cooks")
                        .font(Font.custom("Nunito-SemiBold", size: 15))
                        .foregroundColor(.white)
                        .frame(height: 46)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.nommieGreen))
                }
                Button(action: onLogPlate) {
                    Text("+ Log a plate")
                        .font(Font.custom("Nunito-SemiBold", size: 15))
                        .foregroundColor(.nommieBrown)
                        .frame(height: 46)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).stroke(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
    }
}

// Helper to make String conform to Identifiable for sheet(item:)
private struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

#Preview {
    HomeFeedView().environmentObject(AuthViewModel())
}
