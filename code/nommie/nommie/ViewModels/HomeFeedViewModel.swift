import SwiftUI
import Combine
import FirebaseFirestore

class HomeFeedViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var selectedTag: String? = nil
    @Published var likedRecipeIds: Set<String> = []
    @Published var followingIdSet: Set<String> = []
    @Published var blockedIdSet: Set<String> = []
    @Published var authorPhotoById: [String: String] = [:]

    // Weekly overview (current user's plates in the last 7 days)
    @Published var platesThisWeek: Int = 0
    @Published var avgProteinThisWeek: Int = 0

    private let db = Firestore.firestore()
    private let userService = UserService()

    func removeRecipe(id: String) {
        recipes.removeAll { $0.id == id }
    }

    /// Optimistic like toggle — the UI flips instantly, Firestore catches up,
    /// and cloud triggers maintain the real counters.
    func toggleLike(recipeId: String, userId: String?, username: String?) {
        guard let userId, let username else { return }
        guard let idx = recipes.firstIndex(where: { $0.id == recipeId }) else { return }

        if likedRecipeIds.contains(recipeId) {
            likedRecipeIds.remove(recipeId)
            recipes[idx].likeCount = max(0, recipes[idx].likeCount - 1)
            recipes[idx].recentLikers.removeAll { $0.userId == userId }
            Task { try? await userService.unlikeRecipe(userId: userId, recipeId: recipeId) }
        } else {
            likedRecipeIds.insert(recipeId)
            recipes[idx].likeCount += 1
            recipes[idx].recentLikers.append(RecipeLiker(userId: userId, username: username))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            NommieAnalytics.likeTapped()
            Task { try? await userService.likeRecipe(userId: userId, username: username, recipeId: recipeId) }
        }
    }

    var availableTags: [String] {
        var counts: [String: Int] = [:]
        for recipe in recipes {
            for tag in recipe.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.map { $0.key }
    }

    var filteredRecipes: [Recipe] {
        guard let tag = selectedTag else { return recipes }
        return recipes.filter { $0.tags.contains(tag) }
    }

    /// Fetches only the current user's own recipes + recipes from people they follow.
    /// A brand-new account with no follows correctly sees an empty feed.
    func fetchAllRecipes(currentUserId: String?) async {
        guard let currentUserId else {
            await MainActor.run { isLoading = false }
            return
        }

        await MainActor.run { isLoading = true; errorMessage = "" }

        do {
            // Who does this user follow?
            let followSnap = try await db.collection("follows")
                .whereField("followerId", isEqualTo: currentUserId)
                .getDocuments()
            let followingIds = followSnap.documents.compactMap {
                $0.data()["followingId"] as? String
            }

            // Feed = own recipes + followed users' recipes, minus anyone blocked
            let blockedIds = (try? await userService.fetchBlockedUserIds(blockerId: currentUserId)) ?? []
            let feedUserIds = Array(Set([currentUserId] + followingIds).subtracting(blockedIds))

            // Firestore "in" limit is 30 — chunk if someone follows many people
            var allRecipes: [Recipe] = []
            let chunks = stride(from: 0, to: feedUserIds.count, by: 30).map {
                Array(feedUserIds[$0..<min($0 + 30, feedUserIds.count)])
            }
            for chunk in chunks {
                let snap = try await db.collection("recipes")
                    .whereField("userId", in: chunk)
                    .getDocuments()
                allRecipes += snap.documents.compactMap { Recipe(from: $0.data()) }
            }

            // Sort client-side (avoids composite index requirement)
            let sorted = allRecipes.sorted { $0.createdAt > $1.createdAt }
            let (weekCount, avgProtein) = Self.weeklyStats(from: sorted, userId: currentUserId)

            // Which of these has the current user liked?
            let liked = (try? await userService.fetchLikedRecipeIds(
                userId: currentUserId,
                recipeIds: sorted.map { $0.id }
            )) ?? []

            // Author avatars for the visible cards
            let authorIds = Array(Set(sorted.map { $0.userId }))
            let authorMap = (try? await userService.fetchUserMap(ids: authorIds)) ?? [:]

            await MainActor.run {
                self.recipes = sorted
                self.likedRecipeIds = liked
                self.authorPhotoById = authorMap.mapValues { $0.photoURL }
                self.followingIdSet = Set(followingIds)
                self.blockedIdSet = blockedIds
                self.platesThisWeek = weekCount
                self.avgProteinThisWeek = avgProtein
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't load the feed. Pull down to try again."
                self.isLoading = false
            }
        }
    }

    private static func weeklyStats(from recipes: [Recipe], userId: String?) -> (count: Int, avgProtein: Int) {
        guard let userId else { return (0, 0) }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let mine = recipes.filter { $0.userId == userId && $0.createdAt >= weekAgo }
        guard !mine.isEmpty else { return (0, 0) }
        let totalProtein = mine.reduce(0) { $0 + $1.macros.protein }
        return (mine.count, totalProtein / mine.count)
    }
}
