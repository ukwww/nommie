import SwiftUI
import Combine
import FirebaseFirestore

class ProfileViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var savedRecipes: [Recipe] = []
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var selectedTag: String? = nil
    @Published var platesThisWeek: Int = 0

    private let db = Firestore.firestore()
    private let userService = UserService()

    func removeRecipe(id: String) {
        recipes.removeAll { $0.id == id }
    }

    var availableTags: [String] {
        var counts: [String: Int] = [:]
        for recipe in recipes + savedRecipes {
            for tag in recipe.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.map { $0.key }
    }

    var filteredRecipes: [Recipe] {
        guard let tag = selectedTag else { return recipes }
        return recipes.filter { $0.tags.contains(tag) }
    }

    var filteredSavedRecipes: [Recipe] {
        guard let tag = selectedTag else { return savedRecipes }
        return savedRecipes.filter { $0.tags.contains(tag) }
    }

    func fetchRecipes(for userID: String) async {
        await MainActor.run { isLoading = true }
        do {
            let snapshot = try await db.collection("recipes")
                .whereField("userId", isEqualTo: userID)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            let fetched = snapshot.documents.compactMap { Recipe(from: $0.data()) }
            let weekCount = Self.weeklyPlatesCount(from: fetched)
            await MainActor.run {
                self.recipes = fetched
                self.platesThisWeek = weekCount
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't load your recipes."
                self.isLoading = false
            }
        }
    }

    func fetchSavedRecipes(for userID: String) async {
        do {
            let fetched = try await userService.fetchSavedRecipes(userId: userID)
            await MainActor.run { self.savedRecipes = fetched }
        } catch {
            await MainActor.run { self.errorMessage = "Couldn't load saved recipes." }
        }
    }

    func fetchCounts(for userID: String) async {
        do {
            let followers = try await userService.fetchFollowerCount(userId: userID)
            let following = try await userService.fetchFollowingCount(userId: userID)
            await MainActor.run {
                self.followerCount = followers
                self.followingCount = following
            }
        } catch {}
    }

    private static func weeklyPlatesCount(from recipes: [Recipe]) -> Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return recipes.filter { $0.createdAt >= weekAgo }.count
    }
}
