import SwiftUI
import Combine

// Search any recipe on nommie — "high protein", "pasta", "chicken" — matched
// against each recipe's denormalized search terms. This is the cold-start
// escape hatch: even with no friends, a new user can find recipes to cook.
struct RecipeSearchView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [Recipe] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var blockedIds: Set<String> = []
    @State private var selectedRecipe: Recipe? = nil
    @State private var cancellable: AnyCancellable? = nil
    @State private var recentlyViewed: [Recipe] = []
    @FocusState private var isFocused: Bool

    private let userService = UserService()
    private let suggestions = ["High protein", "Low carb", "High fiber", "Pasta", "Chicken", "Dessert", "Breakfast", "Vegan"]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Search recipes")
                        .font(Font.custom("Lora-SemiBold", size: 20))
                        .foregroundColor(.nommieBrown)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.nommieBrown.opacity(0.5))
                            .frame(width: 30, height: 30)
                            .background(Circle().strokeBorder(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(.nommieBrown.opacity(0.4))
                    TextField("Try \"high protein\" or a dish name", text: $query)
                        .font(NommieFont.bodyRegular.font())
                        .foregroundColor(.nommieBrown)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onChange(of: query) { _, newValue in debounceSearch(newValue) }
                    if isSearching {
                        ProgressView().scaleEffect(0.8)
                    } else if !query.isEmpty {
                        Button(action: { query = ""; results = []; hasSearched = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.nommieBrown.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nommieBrown.opacity(0.12), lineWidth: 1))
                .padding(.horizontal, 20)

                if query.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            RecentlyViewedStrip(recipes: recentlyViewed) { recipe in
                                selectedRecipe = recipe
                            }
                            .padding(.top, 16)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Try searching")
                                    .font(Font.custom("Nunito-SemiBold", size: 13))
                                    .foregroundColor(.nommieBrown.opacity(0.5))
                                FlowChips(items: suggestions) { chip in
                                    query = chip
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                } else if hasSearched && results.isEmpty && !isSearching {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 34))
                            .foregroundColor(.nommieGreen.opacity(0.3))
                        Text("No recipes for \"\(query)\"")
                            .font(Font.custom("Nunito-SemiBold", size: 15))
                            .foregroundColor(.nommieBrown.opacity(0.5))
                        Text("Try a broader term or a single ingredient.")
                            .font(Font.custom("Nunito-Regular", size: 13))
                            .foregroundColor(.nommieBrown.opacity(0.4))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(results) { recipe in
                                Button(action: { selectedRecipe = recipe }) {
                                    RecipeCardView(recipe: recipe, thumbnail: true, currentUserId: authViewModel.currentNommieUser?.id)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(
                recipe: recipe,
                isOwner: recipe.userId == authViewModel.currentNommieUser?.id
            )
            .environmentObject(authViewModel)
        }
        .task {
            recentlyViewed = RecentlyViewed.all()
            if let uid = authViewModel.currentNommieUser?.id {
                blockedIds = (try? await userService.fetchBlockedUserIds(blockerId: uid)) ?? []
            }
            isFocused = true
        }
    }

    private func debounceSearch(_ text: String) {
        cancellable?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { results = []; hasSearched = false; return }
        isSearching = true
        cancellable = Just(trimmed)
            .delay(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { q in
                Task {
                    let found = (try? await userService.searchRecipes(term: q, blockedIds: blockedIds)) ?? []
                    await MainActor.run {
                        self.results = found
                        self.isSearching = false
                        self.hasSearched = true
                    }
                }
            }
    }
}

// Simple wrapping chip row for search suggestions.
private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        let screenWidth = UIScreen.main.bounds.width - 40

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                chip(item)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > screenWidth {
                            width = 0
                            height -= d.height + 10
                        }
                        let result = width
                        if item == items.last { width = 0 } else { width -= d.width + 10 }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last { height = 0 }
                        return result
                    }
            }
        }
        .frame(height: 120, alignment: .topLeading)
    }

    private func chip(_ text: String) -> some View {
        Button(action: { onTap(text) }) {
            Text(text)
                .font(Font.custom("Nunito-SemiBold", size: 14))
                .foregroundColor(.nommieGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.nommieGreen.opacity(0.1)))
                .overlay(Capsule().stroke(Color.nommieGreen.opacity(0.35), lineWidth: 1))
        }
    }
}
