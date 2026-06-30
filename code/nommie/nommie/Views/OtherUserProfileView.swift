import SwiftUI
import FirebaseFirestore

struct OtherUserProfileView: View {
    let username: String

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var recipes: [Recipe] = []
    @State private var followerCount: Int = 0
    @State private var recipeCount: Int = 0
    @State private var isFollowing: Bool = false
    @State private var isFollowLoading: Bool = false
    @State private var isLoading: Bool = true
    @State private var targetUserId: String = ""
    @State private var selectedRecipe: Recipe? = nil
    @State private var replateSource: Recipe? = nil
    @State private var showingCreation: Bool = false

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
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                .padding(.top, NommieTheme.Padding.large)

                if isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .nommieGreen))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Stats + follow
                            VStack(spacing: 12) {
                                HStack(spacing: 28) {
                                    ProfileStat(value: "\(recipeCount)", label: "plates")
                                    ProfileStat(value: "\(followerCount)", label: "followers")
                                }
                                .padding(.top, 8)

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

                            if recipes.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "book.closed")
                                        .font(.system(size: 40))
                                        .foregroundColor(.nommieGreen.opacity(0.3))
                                    Text("No recipes yet")
                                        .font(Font.custom("Nunito-Regular", size: 15))
                                        .foregroundColor(.nommieBrown.opacity(0.5))
                                }
                                .padding(.top, 48)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(recipes) { recipe in
                                        Button(action: { selectedRecipe = recipe }) {
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
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(
                recipe: recipe,
                isOwner: false,
                onReplate: { source in
                    replateSource = source
                }
            )
            .environmentObject(authViewModel)
        }
        .fullScreenCover(item: $replateSource) { source in
            RecipeCreationView(isPresented: Binding(
                get: { replateSource != nil },
                set: { if !$0 { replateSource = nil } }
            ), replateSource: source)
            .environmentObject(authViewModel)
        }
        .task {
            await loadProfile()
            NommieAnalytics.otherProfileViewed()
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
            await MainActor.run { targetUserId = uid }

            // Parallel fetches for recipes and follower count
            async let recipesTask = db.collection("recipes")
                .whereField("userId", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            async let followerTask = userService.fetchFollowerCount(userId: uid)

            let (snap, followers) = try await (recipesTask, followerTask)

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

#Preview {
    OtherUserProfileView(username: "tomcooks")
        .environmentObject(AuthViewModel())
}
