import SwiftUI
import Combine
import FirebaseFirestore

class HomeFeedViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var selectedTag: String? = nil

    // Weekly overview (current user's plates in the last 7 days)
    @Published var platesThisWeek: Int = 0
    @Published var avgProteinThisWeek: Int = 0

    private let db = Firestore.firestore()

    func removeRecipe(id: String) {
        recipes.removeAll { $0.id == id }
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

            // Feed = own recipes + followed users' recipes
            let feedUserIds = Array(Set([currentUserId] + followingIds))

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

            await MainActor.run {
                self.recipes = sorted
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
