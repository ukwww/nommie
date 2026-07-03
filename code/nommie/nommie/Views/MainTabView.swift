import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var deepLinkedRecipe: Recipe? = nil
    @State private var deepLinkedUsername: IdentifiableDeepLinkUsername? = nil
    private let userService = UserService()

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.nommieBackground)
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            ProfileView()
                .tabItem {
                    Label("My Plates", systemImage: "fork.knife")
                }

            HomeFeedView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
        }
        .accentColor(.nommieGreen)
        .sheet(item: $deepLinkedRecipe) { recipe in
            RecipeDetailView(
                recipe: recipe,
                isOwner: recipe.userId == authViewModel.currentNommieUser?.id,
                onDelete: { }
            )
            .environmentObject(authViewModel)
        }
        .onReceive(authViewModel.$pendingDeepLinkRecipeId) { recipeId in
            guard let id = recipeId else { return }
            authViewModel.pendingDeepLinkRecipeId = nil
            Task { deepLinkedRecipe = try? await userService.fetchRecipe(id: id) }
        }
        .onReceive(authViewModel.$pendingDeepLinkUsername) { username in
            guard let username, !username.isEmpty else { return }
            authViewModel.pendingDeepLinkUsername = nil
            // Own profile is already a tab — only present other users
            if username != authViewModel.currentNommieUser?.username {
                deepLinkedUsername = IdentifiableDeepLinkUsername(value: username)
            }
        }
        .fullScreenCover(item: $deepLinkedUsername) { wrapper in
            OtherUserProfileView(username: wrapper.value)
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
            ))
        }
    }
}

private struct IdentifiableDeepLinkUsername: Identifiable {
    let id = UUID()
    let value: String
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
