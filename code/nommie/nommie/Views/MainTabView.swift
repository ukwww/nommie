import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationsVM = NotificationsViewModel()
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
        ZStack(alignment: .top) {
            TabView {
                HomeFeedView()
                    .tabItem {
                        Label("Discover", systemImage: "frying.pan")
                    }

                ProfileView()
                    .tabItem {
                        Label("My Plates", systemImage: "fork.knife")
                    }
            }
            .accentColor(.nommieGreen)

            // In-app toast for fresh activity
            if let toast = notificationsVM.toast {
                NotificationToast(notification: toast) {
                    notificationsVM.dismissToast()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(5)
            }
        }
        .environmentObject(notificationsVM)
        .onReceive(authViewModel.$currentNommieUser) { user in
            if let id = user?.id {
                notificationsVM.startListening(userId: id)
            } else {
                notificationsVM.stopListening()
            }
        }
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

// Identity must be the value itself: a fresh UUID per render makes SwiftUI
// think the item changed and dismiss whatever it's presenting.
private struct IdentifiableDeepLinkUsername: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Notification Toast

struct NotificationToast: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: notification.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.2)))

                Text(notification.message)
                    .font(Font.custom("Nunito-SemiBold", size: 13))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color.nommieGreen))
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
