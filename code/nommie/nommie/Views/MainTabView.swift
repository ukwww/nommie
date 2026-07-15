import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var notificationsVM = NotificationsViewModel()
    @State private var deepLinkedRecipe: Recipe? = nil
    @State private var deepLinkedUsername: IdentifiableDeepLinkUsername? = nil
    @State private var showLaunchReveal = false
    @State private var selectedTab = 0
    @State private var showingCreate = false
    @State private var firstPlateRecipe: Recipe? = nil
    @State private var showFirstPlateFlow = false
    @State private var showFirstPlateExport = false
    private let userService = UserService()

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack(alignment: .top) {
            // Both tabs stay alive so scroll positions and view models persist,
            // driven by our own bottom bar instead of a native TabView.
            ZStack {
                HomeFeedView()
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)
                ProfileView()
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)
            }

            // Bottom navigation hub
            VStack {
                Spacer()
                NommieBottomBar(
                    selectedTab: $selectedTab,
                    onCreate: { showingCreate = true }
                )
            }
            .ignoresSafeArea(.keyboard)

            // In-app toast for fresh activity
            if let toast = notificationsVM.toast {
                NotificationToast(notification: toast) {
                    notificationsVM.dismissToast()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(5)
            }

            // One-time reveal after onboarding completes
            if showLaunchReveal {
                LaunchRevealView { showLaunchReveal = false }
                    .zIndex(20)
            }

            // Celebration after the first plate
            if showFirstPlateFlow {
                FirstPlateFlowView(
                    onExport: {
                        showFirstPlateFlow = false
                        showFirstPlateExport = true
                    },
                    onSkip: { showFirstPlateFlow = false }
                )
                .zIndex(30)
            }
        }
        .fullScreenCover(isPresented: $showingCreate) {
            RecipeCreationView(isPresented: $showingCreate)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showFirstPlateExport) {
            if let recipe = firstPlateRecipe {
                ExportBottomSheet(recipe: recipe, isPresented: $showFirstPlateExport)
                    .environmentObject(authViewModel)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .firstPlateCreated)) { note in
            guard let recipe = note.object as? Recipe else { return }
            firstPlateRecipe = recipe
            showFirstPlateFlow = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .replayFirstPlateFlow)) { _ in
            // Debug replay: use the user's most recent plate so the export works.
            Task {
                guard let uid = authViewModel.currentNommieUser?.id,
                      let recipe = try? await userService.fetchMostRecentRecipe(userId: uid) else { return }
                await MainActor.run {
                    firstPlateRecipe = recipe
                    showFirstPlateFlow = true
                }
            }
        }
        .environmentObject(notificationsVM)
        .onChange(of: hasSeenOnboarding) { _, seen in
            if seen { showLaunchReveal = true }
        }
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

// MARK: - Bottom navigation hub

struct NommieBottomBar: View {
    @Binding var selectedTab: Int
    let onCreate: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            barButton(index: 0, icon: "frying.pan", label: "Discover")
            Spacer()
            createButton
            Spacer()
            barButton(index: 1, icon: "fork.knife", label: "My Plates")
        }
        .padding(.horizontal, 40)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(
            Color.nommieBackground
                .overlay(
                    Rectangle()
                        .fill(Color.nommieBrown.opacity(0.08))
                        .frame(height: 1),
                    alignment: .top
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func barButton(index: Int, icon: String, label: String) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(Font.custom("Nunito-SemiBold", size: 10))
            }
            .foregroundColor(selectedTab == index ? .nommieGreen : .nommieBrown.opacity(0.4))
            .frame(width: 66)
        }
    }

    private var createButton: some View {
        Button(action: onCreate) {
            ZStack {
                Circle()
                    .fill(Color.nommieGreen)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.nommieGreen.opacity(0.35), radius: 8, x: 0, y: 3)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .offset(y: -10)
        }
    }
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
