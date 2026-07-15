import SwiftUI
import Combine
import FirebaseFirestore

// The standout-macro line for the profile overview box, with its emoji.
struct MacroHighlight {
    let emoji: String
    let text: String
}

class ProfileViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var savedRecipes: [Recipe] = []
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var selectedTags: Set<String> = []
    @Published var sortOption: SortOption = .newest
    @Published var platesThisWeek: Int = 0

    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case mostLiked = "Most liked"
        var id: String { rawValue }
    }

    private let db = Firestore.firestore()
    private let userService = UserService()

    func removeRecipe(id: String) {
        recipes.removeAll { $0.id == id }
    }

    // A warm, varied insight about the standout macro of the last 5 plates.
    // Scored against rough per-recipe baselines, then nudged toward protein
    // and fiber so the line stays interesting — carbs and sugar only surface
    // when they clearly dominate. Calories are ignored.
    var recentMacroInsight: MacroHighlight? {
        let recent = Array(recipes.prefix(5))
        guard !recent.isEmpty else { return nil }

        let n = Double(recent.count)
        let avgProtein = Double(recent.reduce(0) { $0 + $1.macros.protein }) / n
        let avgCarbs   = Double(recent.reduce(0) { $0 + $1.macros.carbs }) / n
        let avgFat     = Double(recent.reduce(0) { $0 + $1.macros.fat }) / n
        let avgFiber   = Double(recent.reduce(0) { $0 + $1.macros.fiber }) / n
        let avgSugar   = Double(recent.reduce(0) { $0 + $1.macros.sugar }) / n

        // score = (avg / baseline) * notability bias
        let scores: [(key: String, score: Double)] = [
            ("protein", avgProtein / 20.0 * 1.15),
            ("fiber",   avgFiber   / 6.0  * 1.20),
            ("fat",     avgFat     / 18.0 * 1.00),
            ("carbs",   avgCarbs   / 45.0 * 0.90),
            ("sugar",   avgSugar   / 12.0 * 0.85)
        ]
        guard let top = scores.max(by: { $0.score < $1.score }), top.score > 0 else { return nil }

        switch top.key {
        case "protein": return MacroHighlight(emoji: "💪", text: "Lately you're cooking protein-rich. Great for building and repairing muscle.")
        case "fiber":   return MacroHighlight(emoji: "🥬", text: "Lately you're cooking fiber-rich. Your gut and digestion love it.")
        case "fat":     return MacroHighlight(emoji: "⚖️", text: "Lately you're leaning into healthy fats. Key for hormones and staying full.")
        case "carbs":   return MacroHighlight(emoji: "⚡", text: "Lately you're carb-forward. Your body's main source of quick energy.")
        case "sugar":   return MacroHighlight(emoji: "🍬", text: "Lately you've got a sweet streak. Quick energy, best enjoyed in balance.")
        default:        return nil
        }
    }

    var availableTags: [String] {
        var counts: [String: Int] = [:]
        for recipe in recipes + savedRecipes {
            for tag in recipe.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.map { $0.key }
    }

    var filteredRecipes: [Recipe] { sorted(applyingFilters(to: recipes)) }
    var filteredSavedRecipes: [Recipe] { sorted(applyingFilters(to: savedRecipes)) }

    // A recipe passes if it carries at least one of the selected tags (OR).
    private func applyingFilters(to list: [Recipe]) -> [Recipe] {
        guard !selectedTags.isEmpty else { return list }
        return list.filter { !Set($0.tags).isDisjoint(with: selectedTags) }
    }

    private func sorted(_ list: [Recipe]) -> [Recipe] {
        switch sortOption {
        case .newest:    return list.sorted { $0.createdAt > $1.createdAt }
        case .oldest:    return list.sorted { $0.createdAt < $1.createdAt }
        case .mostLiked: return list.sorted { $0.likeCount > $1.likeCount }
        }
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
