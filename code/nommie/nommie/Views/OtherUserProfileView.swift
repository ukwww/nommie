import SwiftUI
import FirebaseFirestore

struct OtherUserProfileView: View {
    let username: String

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var recipes: [Recipe] = []
    @State private var savedRecipes: [Recipe] = []
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var recipeCount: Int = 0
    @State private var isFollowing: Bool = false
    @State private var isFollowLoading: Bool = false
    @State private var isLoading: Bool = true
    @State private var selectedTab: ProfileView.ProfileTab = .plates
    @State private var savedLoaded: Bool = false
    @State private var targetUserId: String = ""
    // One sheet binding for recipe/followers/following — stacking multiple
    // .sheet modifiers on the same view makes SwiftUI dismiss them at random.
    @State private var activeSheet: OtherProfileSheet? = nil
    @State private var replateSource: Recipe? = nil
    @State private var showingCreation: Bool = false
    @State private var isBlocked: Bool = false
    @State private var showingBlockConfirm: Bool = false
    @State private var profilePhotoURL: String = ""
    @State private var profileBio: String = ""

    private let db = Firestore.firestore()
    private let userService = UserService()

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.nommieBrown)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text("@\(username)")
                        .font(Font.custom("Lora-SemiBold", size: 17))
                        .foregroundColor(.nommieBrown)
                    Spacer()
                    Menu {
                        if isBlocked {
                            Button("Unblock @\(username)") { unblockUser() }
                        } else {
                            Button("Block @\(username)", role: .destructive) { showingBlockConfirm = true }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.nommieBrown.opacity(0.4))
                            .font(.system(size: 17))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, NommieTheme.Padding.large)

                if isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .nommieGreen))
                    Spacer()
                } else if isBlocked {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 40))
                            .foregroundColor(.nommieBrown.opacity(0.25))
                        Text("You've blocked @\(username)")
                            .font(Font.custom("Nunito-SemiBold", size: 15))
                            .foregroundColor(.nommieBrown.opacity(0.6))
                        Text("Their recipes are hidden from you.")
                            .font(Font.custom("Nunito-Regular", size: 13))
                            .foregroundColor(.nommieBrown.opacity(0.4))
                        Button(action: unblockUser) {
                            Text("Unblock")
                                .font(Font.custom("Nunito-SemiBold", size: 15))
                                .foregroundColor(.nommieGreen)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .overlay(Capsule().stroke(Color.nommieGreen.opacity(0.4), lineWidth: 1.5))
                        }
                        .padding(.top, 6)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Avatar + bio + stats + follow
                            VStack(spacing: 12) {
                                AvatarView(
                                    userId: targetUserId,
                                    username: username,
                                    photoURL: profilePhotoURL,
                                    size: 112
                                )
                                .padding(.top, 8)

                                if !profileBio.isEmpty {
                                    Text(profileBio)
                                        .font(Font.custom("Nunito-Regular", size: 14))
                                        .foregroundColor(.nommieBrown.opacity(0.65))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }

                                HStack(spacing: 28) {
                                    ProfileStat(value: "\(recipeCount)", label: "plates")
                                    Button(action: { activeSheet = .followers }) {
                                        ProfileStat(value: "\(followerCount)", label: "followers")
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    Button(action: { activeSheet = .following }) {
                                        ProfileStat(value: "\(followingCount)", label: "following")
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Button(action: toggleFollow) {
                                    HStack(spacing: 6) {
                                        if isFollowLoading {
                                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: isFollowing ? .nommieGreen : .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Text(isFollowing ? "Following" : "Follow")
                                                .font(Font.custom("Nunito-SemiBold", size: 15))
                                        }
                                    }
                                    .foregroundColor(isFollowing ? .nommieGreen : .white)
                                    .frame(width: 120, height: 38)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isFollowing ? Color.clear : Color.nommieGreen)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.nommieGreen, lineWidth: 1.5)
                                            )
                                    )
                                }
                                .disabled(isFollowLoading)
                            }
                            .padding(.bottom, NommieTheme.Padding.large)

                            Divider().padding(.horizontal, NommieTheme.Padding.large)

                            // Plates / Saved tab picker
                            HStack(spacing: 0) {
                                TabButton(title: "Plates", icon: "square.grid.2x2", isSelected: selectedTab == .plates) {
                                    selectedTab = .plates
                                }
                                TabButton(title: "Saved", icon: "bookmark", isSelected: selectedTab == .saved) {
                                    selectedTab = .saved
                                    loadSavedIfNeeded()
                                }
                            }
                            .padding(.horizontal, NommieTheme.Padding.large)
                            .padding(.top, NommieTheme.Padding.medium)

                            let shownRecipes = selectedTab == .plates ? recipes : savedRecipes
                            if shownRecipes.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: selectedTab == .plates ? "book.closed" : "bookmark")
                                        .font(.system(size: 40))
                                        .foregroundColor(.nommieGreen.opacity(0.3))
                                    Text(selectedTab == .plates ? "No recipes yet" : "No saved recipes yet")
                                        .font(Font.custom("Nunito-Regular", size: 15))
                                        .foregroundColor(.nommieBrown.opacity(0.5))
                                }
                                .padding(.top, 48)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(shownRecipes) { recipe in
                                        Button(action: { activeSheet = .recipe(recipe) }) {
                                            RecipeCardView(recipe: recipe, thumbnail: true, currentUserId: authViewModel.currentNommieUser?.id)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, NommieTheme.Padding.medium)
                                .padding(.top, NommieTheme.Padding.medium)
                                .padding(.bottom, 40)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .recipe(let recipe):
                RecipeDetailView(
                    recipe: recipe,
                    isOwner: recipe.userId == authViewModel.currentNommieUser?.id,
                    onReplate: { source in
                        replateSource = source
                    }
                )
                .environmentObject(authViewModel)
            case .followers:
                FollowListView(userId: targetUserId, type: .followers)
                    .environmentObject(authViewModel)
            case .following:
                FollowListView(userId: targetUserId, type: .following)
                    .environmentObject(authViewModel)
            }
        }
        .fullScreenCover(item: $replateSource) { source in
            RecipeCreationView(isPresented: Binding(
                get: { replateSource != nil },
                set: { if !$0 { replateSource = nil } }
            ), replateSource: source)
            .environmentObject(authViewModel)
        }
        .alert("Block @\(username)?", isPresented: $showingBlockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) { blockUser() }
        } message: {
            Text("They won't appear in your feed or search results, and you'll unfollow each other.")
        }
        .task {
            await loadProfile()
            NommieAnalytics.otherProfileViewed()
        }
    }

    private func loadSavedIfNeeded() {
        guard !savedLoaded, !targetUserId.isEmpty else { return }
        savedLoaded = true
        Task {
            let fetched = (try? await userService.fetchSavedRecipes(userId: targetUserId)) ?? []
            await MainActor.run { savedRecipes = fetched }
        }
    }

    private func blockUser() {
        guard let currentUserId = authViewModel.currentNommieUser?.id, !targetUserId.isEmpty else { return }
        Task {
            try? await userService.blockUser(blockerId: currentUserId, blockedId: targetUserId)
            await MainActor.run {
                isBlocked = true
                isFollowing = false
            }
            NotificationCenter.default.post(name: .profileNeedsRefresh, object: nil)
        }
    }

    private func unblockUser() {
        guard let currentUserId = authViewModel.currentNommieUser?.id, !targetUserId.isEmpty else { return }
        Task {
            try? await userService.unblockUser(blockerId: currentUserId, blockedId: targetUserId)
            await MainActor.run { isBlocked = false }
            NotificationCenter.default.post(name: .profileNeedsRefresh, object: nil)
        }
    }

    private func loadProfile() async {
        do {
            // Fetch user by username
            guard let user = try await userService.fetchUserProfileByUsername(username) else {
                await MainActor.run { isLoading = false }
                return
            }
            let uid = user.id
            await MainActor.run {
                targetUserId = uid
                profilePhotoURL = user.photoURL
                profileBio = user.bio
            }

            if let currentUserId = authViewModel.currentNommieUser?.id {
                let blocked = (try? await userService.isBlocked(blockerId: currentUserId, blockedId: uid)) ?? false
                await MainActor.run { isBlocked = blocked }
            }

            // Parallel fetches for recipes and follow counts
            async let recipesTask = db.collection("recipes")
                .whereField("userId", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            async let followerTask = userService.fetchFollowerCount(userId: uid)
            async let followingTask = userService.fetchFollowingCount(userId: uid)

            let (snap, followers, followingTotal) = try await (recipesTask, followerTask, followingTask)

            // Follow check needs current user ID — done after parallel fetch
            var following = false
            if let currentUserId = authViewModel.currentNommieUser?.id {
                following = (try? await userService.isFollowing(followerId: currentUserId, followingId: uid)) ?? false
            }

            let fetched = snap.documents.compactMap { Recipe(from: $0.data()) }
            await MainActor.run {
                recipes = fetched
                recipeCount = fetched.count
                followerCount = followers
                followingCount = followingTotal
                isFollowing = following
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func toggleFollow() {
        guard let currentUserId = authViewModel.currentNommieUser?.id else { return }
        isFollowLoading = true
        NommieAnalytics.followTapped()
        Task {
            do {
                if isFollowing {
                    try await userService.unfollowUser(followerId: currentUserId, followingId: targetUserId)
                    await MainActor.run {
                        isFollowing = false
                        followerCount = max(0, followerCount - 1)
                        isFollowLoading = false
                    }
                } else {
                    try await userService.followUser(followerId: currentUserId, followingId: targetUserId)
                    await MainActor.run {
                        isFollowing = true
                        followerCount += 1
                        isFollowLoading = false
                    }
                }
                NotificationCenter.default.post(name: .profileNeedsRefresh, object: nil)
            } catch {
                await MainActor.run { isFollowLoading = false }
            }
        }
    }
}

// The single sheet route for this screen — one binding, no modifier conflicts.
private enum OtherProfileSheet: Identifiable {
    case recipe(Recipe)
    case followers
    case following

    var id: String {
        switch self {
        case .recipe(let recipe): return "recipe_\(recipe.id)"
        case .followers: return "followers"
        case .following: return "following"
        }
    }
}

#Preview {
    OtherUserProfileView(username: "tomcooks")
        .environmentObject(AuthViewModel())
}
