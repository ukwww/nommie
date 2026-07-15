import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationsVM: NotificationsViewModel
    @StateObject private var viewModel = HomeFeedViewModel()
    @State private var showingRecipeCreation = false
    @State private var replateSource: Recipe? = nil
    @State private var recentlyViewed: [Recipe] = []
    // One sheet route — stacking .sheet modifiers dismisses them at random.
    @State private var activeSheet: FeedSheet? = nil
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
                                    onFindFriends: { activeSheet = .search },
                                    onLogPlate: { showingRecipeCreation = true }
                                )
                                .padding(.vertical, 28)
                                .padding(.horizontal, 4)

                                GhostFeedCard().opacity(0.35)
                            }
                        }
                    } else {
                        RecentlyViewedStrip(recipes: recentlyViewed) { recipe in
                            activeSheet = .recipe(recipe)
                        }
                        .padding(.bottom, recentlyViewed.isEmpty ? 0 : 18)

                        LazyVStack(spacing: 18) {
                            ForEach(viewModel.filteredRecipes) { recipe in
                                Button(action: { activeSheet = .recipe(recipe) }) {
                                    RecipeCardView(
                                        recipe: recipe,
                                        compact: true,
                                        currentUserId: currentUserId,
                                        likedByMe: viewModel.likedRecipeIds.contains(recipe.id),
                                        followingIds: viewModel.followingIdSet,
                                        blockedIds: viewModel.blockedIdSet,
                                        authorPhotoURL: viewModel.authorPhotoById[recipe.userId],
                                        onUsernameTap: {
                                            if recipe.userId != currentUserId {
                                                activeSheet = .profile(recipe.username)
                                            }
                                        },
                                        onLikeTap: {
                                            viewModel.toggleLike(
                                                recipeId: recipe.id,
                                                userId: currentUserId,
                                                username: authViewModel.currentNommieUser?.username
                                            )
                                        },
                                        onLikerTap: { likerUsername in
                                            activeSheet = .profile(likerUsername)
                                        },
                                        onCommentTap: {
                                            activeSheet = .comments(recipe)
                                        },
                                        onDoubleTapLike: {
                                            // Double-tap only ever likes, never unlikes
                                            if !viewModel.likedRecipeIds.contains(recipe.id) {
                                                viewModel.toggleLike(
                                                    recipeId: recipe.id,
                                                    userId: currentUserId,
                                                    username: authViewModel.currentNommieUser?.username
                                                )
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
            .refreshable {
                await viewModel.fetchAllRecipes(currentUserId: currentUserId)
            }

            // Sticky header
            HStack(alignment: .center, spacing: 14) {
                Text("nommie ")
                    .font(Font.custom("Caveat-Bold", size: 36))
                    .foregroundColor(.nommieGreen)
                Spacer()

                Spacer(minLength: 0)

                // Search recipes
                Button(action: { activeSheet = .recipeSearch }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 19))
                        .foregroundColor(.nommieBrown.opacity(0.7))
                        .frame(width: 32, height: 32)
                }

                // Activity bell with unread badge
                Button(action: { activeSheet = .notifications }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: notificationsVM.unreadCount > 0 ? "bell.fill" : "bell")
                            .font(.system(size: 19))
                            .foregroundColor(.nommieBrown.opacity(0.7))
                            .frame(width: 32, height: 32)

                        if notificationsVM.unreadCount > 0 {
                            Text(notificationsVM.unreadCount > 9 ? "9+" : "\(notificationsVM.unreadCount)")
                                .font(Font.custom("Nunito-Bold", size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Capsule().fill(Color.nommieBlush))
                                .offset(x: 3, y: -2)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(Color.nommieBackground)

        }
        .sheet(item: $activeSheet, onDismiss: { recentlyViewed = RecentlyViewed.all() }) { sheet in
            switch sheet {
            case .search:
                UserSearchView().environmentObject(authViewModel)
            case .recipe(let recipe):
                RecipeDetailView(
                    recipe: recipe,
                    isOwner: recipe.userId == currentUserId,
                    onDelete: { viewModel.removeRecipe(id: recipe.id) },
                    onReplate: { source in replateSource = source }
                )
                .environmentObject(authViewModel)
            case .profile(let username):
                OtherUserProfileView(username: username)
                    .environmentObject(authViewModel)
            case .notifications:
                NotificationsView()
                    .environmentObject(authViewModel)
                    .environmentObject(notificationsVM)
            case .comments(let recipe):
                CommentsView(recipe: recipe)
                    .environmentObject(authViewModel)
            case .recipeSearch:
                RecipeSearchView()
                    .environmentObject(authViewModel)
            }
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
            recentlyViewed = RecentlyViewed.all()
            Task { await viewModel.fetchAllRecipes(currentUserId: currentUserId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileNeedsRefresh)) { _ in
            // Edits, saves, follows, and blocks all invalidate feed cards —
            // without this, an edited recipe kept its stale copy on the feed.
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
    let highlight: MacroHighlight?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(plates)")
                    .font(Font.custom("Nunito-Bold", size: 20))
                    .foregroundColor(.nommieYellow)
                Text(plates == 1 ? "plate this week" : "plates this week")
                    .font(Font.custom("Nunito-SemiBold", size: 14))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, highlight == nil ? 16 : 12)

            if let highlight {
                Divider().background(Color.white.opacity(0.2))
                    .padding(.horizontal, 20)
                HStack(alignment: .top, spacing: 8) {
                    Text(highlight.emoji)
                        .font(.system(size: 15))
                    Text(highlight.text)
                        .font(Font.custom("Nunito-Regular", size: 13.5))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// The feed's single sheet route — one binding, no modifier conflicts.
private enum FeedSheet: Identifiable {
    case search
    case recipeSearch
    case recipe(Recipe)
    case profile(String)
    case notifications
    case comments(Recipe)

    var id: String {
        switch self {
        case .search: return "search"
        case .recipeSearch: return "recipeSearch"
        case .recipe(let recipe): return "recipe_\(recipe.id)"
        case .profile(let username): return "profile_\(username)"
        case .notifications: return "notifications"
        case .comments(let recipe): return "comments_\(recipe.id)"
        }
    }
}

#Preview {
    HomeFeedView().environmentObject(AuthViewModel())
}
