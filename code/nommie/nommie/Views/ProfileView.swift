import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingQRCode = false
    @State private var showingSearch = false
    @State private var selectedRecipe: Recipe? = nil
    @State private var selectedTab: ProfileTab = .plates
    @State private var showingDeleteConfirm = false
    @State private var showingAppleDeleteSheet = false
    @State private var deletePassword = ""
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var weeklyExpanded = false
    @State private var showingRecipeCreation = false

    enum ProfileTab { case plates, saved }

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Profile header
                    VStack(alignment: .leading, spacing: 0) {
                        // Username row + icon buttons
                        HStack(alignment: .top) {
                            Text("@\(authViewModel.currentNommieUser?.username ?? "")")
                                .font(Font.custom("Lora-Bold", size: 22))
                                .foregroundColor(.nommieBrown)
                            Spacer()
                            HStack(spacing: 10) {
                                ProfileIconButton(icon: "person.badge.plus") {
                                    showingSearch = true
                                }
                                ProfileIconButton(icon: "qrcode") {
                                    showingQRCode = true
                                }
                            }
                        }
                        .padding(.bottom, 16)

                        // Plates count — large, prominent
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(viewModel.recipes.count)")
                                .font(Font.custom("Nunito-Bold", size: 48))
                                .foregroundColor(.nommieGreen)
                            Text(viewModel.recipes.count == 1 ? "plate" : "plates")
                                .font(Font.custom("Lora-SemiBold", size: 20))
                                .foregroundColor(.nommieBrown.opacity(0.65))
                                .padding(.bottom, 4)
                        }
                        .padding(.bottom, 10)

                        // Followers / Following — small, de-emphasised
                        HStack(spacing: 4) {
                            Button(action: { showingFollowers = true }) {
                                HStack(spacing: 3) {
                                    Text("\(viewModel.followerCount)")
                                        .font(Font.custom("Nunito-SemiBold", size: 13))
                                        .foregroundColor(.nommieBrown)
                                    Text("followers")
                                        .font(Font.custom("Nunito-Regular", size: 13))
                                        .foregroundColor(.nommieBrown.opacity(0.45))
                                }
                            }
                            Text("·")
                                .font(Font.custom("Nunito-Regular", size: 13))
                                .foregroundColor(.nommieBrown.opacity(0.3))
                            Button(action: { showingFollowing = true }) {
                                HStack(spacing: 3) {
                                    Text("\(viewModel.followingCount)")
                                        .font(Font.custom("Nunito-SemiBold", size: 13))
                                        .foregroundColor(.nommieBrown)
                                    Text("following")
                                        .font(Font.custom("Nunito-Regular", size: 13))
                                        .foregroundColor(.nommieBrown.opacity(0.45))
                                }
                            }
                        }
                        .padding(.bottom, 16)

                        // New plate CTA
                        Button(action: { showingRecipeCreation = true }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.nommieGreen.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.nommieGreen)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Log a new plate")
                                        .font(Font.custom("Nunito-Bold", size: 15))
                                        .foregroundColor(.nommieBrown)
                                    Text("Create your next recipe card")
                                        .font(Font.custom("Nunito-Regular", size: 12))
                                        .foregroundColor(.nommieBrown.opacity(0.45))
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.nommieGreen.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.nommieGreen.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            )
                        }
                        .padding(.bottom, 14)

                        // Weekly recap banner
                        WeeklyOverviewBanner(
                            plates: viewModel.platesThisWeek,
                            exportCount: authViewModel.currentNommieUser?.exportCount ?? 0,
                            expanded: $weeklyExpanded
                        )
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .padding(.top, NommieTheme.Padding.large)
                    .padding(.bottom, NommieTheme.Padding.large)

                    Divider().padding(.horizontal, NommieTheme.Padding.large)

                    // Plates / Saved tab picker
                    HStack(spacing: 0) {
                        TabButton(title: "Plates", icon: "square.grid.2x2", isSelected: selectedTab == .plates) {
                            selectedTab = .plates
                        }
                        TabButton(title: "Saved", icon: "bookmark", isSelected: selectedTab == .saved) {
                            selectedTab = .saved
                            if let uid = authViewModel.currentNommieUser?.id {
                                Task { await viewModel.fetchSavedRecipes(for: uid) }
                            }
                        }
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .padding(.top, NommieTheme.Padding.medium)
                    .padding(.bottom, 4)

                    // Tag filter pills
                    if !viewModel.availableTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                FilterPill(label: "All", isSelected: viewModel.selectedTag == nil) {
                                    viewModel.selectedTag = nil
                                }
                                ForEach(viewModel.availableTags, id: \.self) { tag in
                                    FilterPill(label: tag, isSelected: viewModel.selectedTag == tag) {
                                        viewModel.selectedTag = (viewModel.selectedTag == tag) ? nil : tag
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 10)
                    }

                    // Grid content
                    if selectedTab == .plates {
                        platesGrid
                    } else {
                        savedGrid
                    }

                    // Sign out + delete account at the bottom
                    VStack(spacing: 14) {
                        Button(action: { authViewModel.signOut() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 13))
                                Text("Sign Out")
                                    .font(NommieFont.bodySemiBold.font())
                            }
                            .foregroundColor(.nommieGreen)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 11)
                            .overlay(Capsule().stroke(Color.nommieGreen.opacity(0.4), lineWidth: 1.5))
                        }

                        Button(action: {
                            if let url = URL(string: "mailto:ubinkw@gmail.com?subject=Nommie%20Support") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Contact Support")
                                .font(NommieFont.caption.font())
                                .foregroundColor(.nommieBrown.opacity(0.4))
                        }

                        Button(action: {
                            if authViewModel.isAppleUser {
                                showingAppleDeleteSheet = true
                            } else {
                                deletePassword = ""
                                showingDeleteConfirm = true
                            }
                        }) {
                            Text("Delete Account")
                                .font(NommieFont.caption.font())
                                .foregroundColor(.nommieBrown.opacity(0.3))
                        }

                        #if DEBUG
                        Button(action: { UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding") }) {
                            Text("Replay Onboarding")
                                .font(NommieFont.caption.font())
                                .foregroundColor(.nommieBrown.opacity(0.2))
                        }
                        #endif
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            UserSearchView().environmentObject(authViewModel)
        }
        .sheet(item: $selectedRecipe) { recipe in
            let isOwner = recipe.userId == authViewModel.currentNommieUser?.id
            RecipeDetailView(recipe: recipe, isOwner: isOwner, onDelete: {
                viewModel.removeRecipe(id: recipe.id)
            })
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(
                username: authViewModel.currentNommieUser?.username ?? "",
                isPresented: $showingQRCode
            )
        }
        .fullScreenCover(isPresented: $showingRecipeCreation, onDismiss: {
            if let uid = authViewModel.currentNommieUser?.id {
                Task { await viewModel.fetchRecipes(for: uid) }
            }
        }) {
            RecipeCreationView(isPresented: $showingRecipeCreation)
                .environmentObject(authViewModel)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirm) {
            SecureField("Password", text: $deletePassword)
            Button("Cancel", role: .cancel) { deletePassword = "" }
            Button("Delete", role: .destructive) {
                Task {
                    _ = await authViewModel.deleteAccount(password: deletePassword)
                    deletePassword = ""
                }
            }
        } message: {
            Text("This permanently deletes your account, recipes, and photos. This can't be undone.")
        }
        .sheet(isPresented: $showingAppleDeleteSheet) {
            AppleDeleteConfirmView(isPresented: $showingAppleDeleteSheet)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingFollowers) {
            if let uid = authViewModel.currentNommieUser?.id {
                FollowListView(userId: uid, type: .followers)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showingFollowing) {
            if let uid = authViewModel.currentNommieUser?.id {
                FollowListView(userId: uid, type: .following)
                    .environmentObject(authViewModel)
            }
        }
        .onAppear {
            if let uid = authViewModel.currentNommieUser?.id {
                Task {
                    await viewModel.fetchRecipes(for: uid)
                    await viewModel.fetchCounts(for: uid)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileNeedsRefresh)) { _ in
            if let uid = authViewModel.currentNommieUser?.id {
                Task {
                    await viewModel.fetchRecipes(for: uid)
                    await viewModel.fetchCounts(for: uid)
                    await viewModel.fetchSavedRecipes(for: uid)
                }
            }
        }
    }

    // MARK: - Plates Grid

    @ViewBuilder
    var platesGrid: some View {
        if viewModel.isLoading {
            VStack(spacing: 20) {
                GhostProfileGrid().opacity(0.5)
                NommieSpinningLogo(size: 32)
            }
        } else if viewModel.filteredRecipes.isEmpty {
            VStack(spacing: 0) {
                GhostProfileGrid().opacity(0.5)

                VStack(spacing: 14) {
                    Text("Make your first card")
                        .font(Font.custom("Lora-Bold", size: 22))
                        .foregroundColor(.nommieBrown)
                    Text("Log a dish and nommie formats it into a card —\nmacros, ingredients, your QR code. Ready to post.")
                        .font(Font.custom("Nunito-Regular", size: 15))
                        .foregroundColor(.nommieBrown.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: {
                        NotificationCenter.default.post(name: .openRecipeCreation, object: nil)
                    }) {
                        Text("+ Create a card")
                            .font(Font.custom("Nunito-SemiBold", size: 15))
                            .foregroundColor(.white)
                            .frame(height: 50)
                            .frame(maxWidth: 240)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.nommieGreen))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
            }
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.filteredRecipes) { recipe in
                    Button(action: { selectedRecipe = recipe }) {
                        RecipeCardView(recipe: recipe, thumbnail: true, currentUserId: authViewModel.currentNommieUser?.id)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, NommieTheme.Padding.medium)
            .padding(.top, NommieTheme.Padding.medium)
        }
    }

    // MARK: - Saved Grid

    @ViewBuilder
    var savedGrid: some View {
        if viewModel.filteredSavedRecipes.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bookmark")
                    .font(.system(size: 40))
                    .foregroundColor(.nommieGreen.opacity(0.3))
                Text("Nothing saved yet")
                    .font(NommieFont.bodyRegular.font())
                    .foregroundColor(.nommieBrown.opacity(0.5))
                Text("Tap the bookmark on any recipe to save it here")
                    .font(NommieFont.caption.font())
                    .foregroundColor(.nommieBrown.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 48)
            .padding(.horizontal, 32)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.filteredSavedRecipes) { recipe in
                    Button(action: { selectedRecipe = recipe }) {
                        RecipeCardView(recipe: recipe, thumbnail: true, currentUserId: authViewModel.currentNommieUser?.id)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, NommieTheme.Padding.medium)
            .padding(.top, NommieTheme.Padding.medium)
        }
    }
}

// MARK: - Profile Stat
struct ProfileStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Font.custom("Nunito-Bold", size: 20))
                .foregroundColor(.nommieBrown)
            Text(label)
                .font(Font.custom("Nunito-Regular", size: 13))
                .foregroundColor(.nommieBrown.opacity(0.5))
        }
    }
}

// MARK: - Profile Icon Button (top-right circular)
struct ProfileIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(.nommieGreen)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nommieBrown.opacity(0.12), lineWidth: 1))
        }
    }
}

// MARK: - Profile Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(Font.custom("Nunito-SemiBold", size: 14))
            }
            .foregroundColor(isSelected ? .nommieGreen : .nommieBrown.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color.nommieGreen : Color.clear)
                    .frame(height: 2),
                alignment: .bottom
            )
        }
    }
}

// MARK: - Profile Action Button
struct ProfileActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.nommieGreen)
                Text(label)
                    .font(NommieFont.caption.font())
                    .foregroundColor(.nommieBrown)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).fill(Color.white.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).stroke(Color.nommieBrown.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - Ghost Profile Grid (skeleton, non-interactive)
struct GhostProfileGrid: View {
    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let block = Color.nommieBrown.opacity(0.06)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(block))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.nommieBrown.opacity(0.12),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    )
            }
        }
        .padding(.horizontal, NommieTheme.Padding.medium)
        .padding(.top, NommieTheme.Padding.medium)
        .allowsHitTesting(false)
    }
}

extension Notification.Name {
    static let openRecipeCreation = Notification.Name("openRecipeCreation")
    static let profileNeedsRefresh = Notification.Name("profileNeedsRefresh")
}

// MARK: - Follow List View
struct FollowListView: View {
    let userId: String
    let type: FollowType
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var users: [NommieUser] = []
    @State private var isLoading = true
    @State private var selectedUsername: String? = nil

    enum FollowType { case followers, following }

    private let userService = UserService()

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(type == .followers ? "Followers" : "Following")
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

                if isLoading {
                    Spacer()
                    NommieSpinningLogo(size: 32)
                    Spacer()
                } else if users.isEmpty {
                    Spacer()
                    Text(type == .followers ? "No followers yet" : "Not following anyone yet")
                        .font(Font.custom("Nunito-Regular", size: 15))
                        .foregroundColor(.nommieBrown.opacity(0.5))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(users) { user in
                                Button(action: { selectedUsername = user.username }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(CardPalettes.paletteForUser(user.id).accent.opacity(0.15))
                                                .frame(width: 40, height: 40)
                                            Text(String(user.username.prefix(1)).uppercased())
                                                .font(Font.custom("Nunito-Bold", size: 16))
                                                .foregroundColor(CardPalettes.paletteForUser(user.id).accent)
                                        }
                                        Text("@\(user.username)")
                                            .font(Font.custom("Nunito-SemiBold", size: 16))
                                            .foregroundColor(.nommieBrown)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13))
                                            .foregroundColor(.nommieBrown.opacity(0.3))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                }
                                Divider().padding(.leading, 72)
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { selectedUsername.map { FollowIdentifiable(value: $0) } },
            set: { selectedUsername = $0?.value }
        )) { wrapper in
            OtherUserProfileView(username: wrapper.value)
                .environmentObject(authViewModel)
        }
        .task { await loadUsers() }
    }

    private func loadUsers() async {
        do {
            let fetched = try await (type == .followers
                ? userService.fetchFollowers(userId: userId)
                : userService.fetchFollowing(userId: userId))
            await MainActor.run { users = fetched; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

private struct AppleDeleteConfirmView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.red.opacity(0.8))
            Text("Delete Account")
                .font(Font.custom("Lora-Bold", size: 24))
                .foregroundColor(.nommieBrown)
            Text("This permanently deletes your account, recipes, and photos. This can't be undone.\n\nConfirm with Apple to proceed.")
                .font(Font.custom("Nunito-Regular", size: 15))
                .foregroundColor(.nommieBrown.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = []
                request.nonce = authViewModel.prepareAppleDeleteAccount()
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    Task {
                        let deleted = await authViewModel.deleteAccountWithApple(authorization: auth)
                        if deleted { isPresented = false }
                    }
                case .failure:
                    break
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            Button("Cancel") { isPresented = false }
                .font(Font.custom("Nunito-Regular", size: 15))
                .foregroundColor(.nommieBrown.opacity(0.4))
            Spacer()
        }
        .background(Color.nommieBackground.ignoresSafeArea())
    }
}

private struct FollowIdentifiable: Identifiable {
    let id = UUID()
    let value: String
}

#Preview {
    ProfileView().environmentObject(AuthViewModel())
}
