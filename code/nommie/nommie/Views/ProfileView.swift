import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingQRCode = false
    @State private var showingSearch = false
    @State private var selectedRecipe: Recipe? = nil
    @State private var selectedTab: ProfileTab = .plates
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingFilters = false

    enum ProfileTab { case plates, saved }

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Profile header
                    VStack(alignment: .leading, spacing: 0) {
                        // Top action row: nommie wordmark (left), then search,
                        // QR, settings on the right.
                        HStack(spacing: 10) {
                            Text("nommie ")
                                .font(Font.custom("Caveat-Bold", size: 32))
                                .foregroundColor(.nommieGreen)
                            Spacer()
                            ProfileIconButton(icon: "person.badge.plus") {
                                showingSearch = true
                            }
                            ProfileIconButton(icon: "square.and.arrow.up") {
                                showingQRCode = true
                            }
                            ProfileIconButton(icon: "gearshape") {
                                showingSettings = true
                            }
                        }
                        .padding(.bottom, 16)

                        // Avatar + username + bio + edit profile
                        HStack(alignment: .top, spacing: 14) {
                            Button(action: { showingEditProfile = true }) {
                                AvatarView(
                                    userId: authViewModel.currentNommieUser?.id ?? "",
                                    username: authViewModel.currentNommieUser?.username ?? "",
                                    photoURL: authViewModel.currentNommieUser?.photoURL,
                                    size: 96
                                )
                                .overlay {
                                    if authViewModel.isUploadingAvatar {
                                        ZStack {
                                            Circle().fill(Color.black.opacity(0.35))
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("@\(authViewModel.currentNommieUser?.username ?? "")")
                                    .font(Font.custom("Lora-Bold", size: 22))
                                    .foregroundColor(.nommieBrown)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                if let bio = authViewModel.currentNommieUser?.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(Font.custom("Nunito-Regular", size: 13))
                                        .foregroundColor(.nommieBrown.opacity(0.6))
                                        .lineLimit(2)
                                }

                                Button(action: { showingEditProfile = true }) {
                                    Text("Edit profile")
                                        .font(Font.custom("Nunito-SemiBold", size: 12))
                                        .foregroundColor(.nommieGreen)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .overlay(Capsule().stroke(Color.nommieGreen.opacity(0.4), lineWidth: 1.2))
                                }
                                .padding(.top, 3)
                            }

                            Spacer()
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

                        // Weekly recap banner
                        WeeklyOverviewBanner(
                            plates: viewModel.platesThisWeek,
                            highlight: viewModel.recentMacroInsight
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

                    // Filters + Sort
                    HStack(spacing: 10) {
                        Button(action: { showingFilters = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 14))
                                Text(viewModel.selectedTags.isEmpty ? "Filters" : "Filters (\(viewModel.selectedTags.count))")
                                    .font(Font.custom("Nunito-SemiBold", size: 13))
                            }
                            .foregroundColor(viewModel.selectedTags.isEmpty ? .nommieBrown.opacity(0.6) : .nommieGreen)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(
                                viewModel.selectedTags.isEmpty ? Color.nommieBrown.opacity(0.2) : Color.nommieGreen.opacity(0.5),
                                lineWidth: 1.3))
                        }

                        Menu {
                            ForEach(ProfileViewModel.SortOption.allCases) { option in
                                Button(action: { viewModel.sortOption = option }) {
                                    if viewModel.sortOption == option {
                                        Label(option.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 13))
                                Text(viewModel.sortOption.rawValue)
                                    .font(Font.custom("Nunito-SemiBold", size: 13))
                            }
                            .foregroundColor(.nommieBrown.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.nommieBrown.opacity(0.2), lineWidth: 1.3))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .padding(.vertical, 12)

                    // Grid content
                    if selectedTab == .plates {
                        platesGrid
                    } else {
                        savedGrid
                    }

                    Color.clear.frame(height: 100)
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            UserSearchView().environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(isPresented: $showingEditProfile)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingFilters) {
            FilterSheet(
                availableTags: viewModel.availableTags,
                selectedTags: $viewModel.selectedTags,
                isPresented: $showingFilters
            )
        }
        .sheet(item: $selectedRecipe) { recipe in
            let isOwner = recipe.userId == authViewModel.currentNommieUser?.id
            RecipeDetailView(recipe: recipe, isOwner: isOwner, onDelete: {
                viewModel.removeRecipe(id: recipe.id)
            })
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingQRCode) {
            ShareProfileView(isPresented: $showingQRCode)
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

// MARK: - Filter Sheet

struct FilterSheet: View {
    let availableTags: [String]
    @Binding var selectedTags: Set<String>
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Filter by tag")
                    .font(Font.custom("Lora-SemiBold", size: 20))
                    .foregroundColor(.nommieBrown)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                if availableTags.isEmpty {
                    Spacer()
                    Text("No tags to filter by yet.")
                        .font(Font.custom("Nunito-Regular", size: 14))
                        .foregroundColor(.nommieBrown.opacity(0.5))
                    Spacer()
                } else {
                    ScrollView {
                        FlowTagLayout(tags: availableTags) { tag in
                            let isOn = selectedTags.contains(tag)
                            Button(action: {
                                if isOn { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                            }) {
                                HStack(spacing: 5) {
                                    if isOn {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    Text(tag)
                                        .font(Font.custom("Nunito-SemiBold", size: 13))
                                }
                                .foregroundColor(isOn ? .white : .nommieBrown.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(isOn ? Color.nommieGreen : Color.white.opacity(0.6)))
                                .overlay(Capsule().stroke(isOn ? Color.clear : Color.nommieBrown.opacity(0.2), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }

                // Actions
                HStack(spacing: 12) {
                    Button(action: { selectedTags.removeAll() }) {
                        Text("Clear")
                            .font(Font.custom("Nunito-SemiBold", size: 16))
                            .foregroundColor(.nommieGreen)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.nommieGreen.opacity(0.4), lineWidth: 1.5))
                    }
                    .opacity(selectedTags.isEmpty ? 0.4 : 1)
                    .disabled(selectedTags.isEmpty)

                    Button(action: { isPresented = false }) {
                        Text("Done")
                            .font(Font.custom("Nunito-SemiBold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.nommieGreen))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .padding(.top, 8)
            }

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .frame(width: 30, height: 30)
                    .background(Circle().strokeBorder(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool

    @State private var showingDeleteConfirm = false
    @State private var showingAppleDeleteSheet = false
    @State private var deletePassword = ""

    private let privacyURL = "https://getnommie.app/privacy.html"
    private let supportMailto = "mailto:ubinkw@gmail.com?subject=Nommie%20Support"

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "nommie v\(v) (\(b))"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.nommieBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(Font.custom("Lora-SemiBold", size: 20))
                    .foregroundColor(.nommieBrown)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)
                    .padding(.bottom, 20)

                VStack(spacing: 0) {
                    settingsRow(icon: "envelope", label: "Contact support") {
                        if let url = URL(string: supportMailto) { UIApplication.shared.open(url) }
                    }
                    rowDivider
                    settingsRow(icon: "doc.text", label: "Privacy policy & terms") {
                        if let url = URL(string: privacyURL) { UIApplication.shared.open(url) }
                    }
                    rowDivider
                    settingsRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign out") {
                        authViewModel.signOut()
                    }
                    rowDivider
                    settingsRow(icon: "trash", label: "Delete account", tint: .nommieBlush) {
                        if authViewModel.isAppleUser {
                            showingAppleDeleteSheet = true
                        } else {
                            deletePassword = ""
                            showingDeleteConfirm = true
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.nommieBrown.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)

                Spacer()

                Text(appVersion)
                    .font(Font.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.nommieBrown.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                #if DEBUG
                VStack(spacing: 10) {
                    Button(action: { UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding") }) {
                        Text("Replay onboarding")
                            .font(Font.custom("Nunito-Regular", size: 12))
                            .foregroundColor(.nommieBrown.opacity(0.25))
                            .frame(maxWidth: .infinity)
                    }
                    Button(action: {
                        isPresented = false
                        NotificationCenter.default.post(name: .replayFirstPlateFlow, object: nil)
                    }) {
                        Text("Replay first-plate flow")
                            .font(Font.custom("Nunito-Regular", size: 12))
                            .foregroundColor(.nommieBrown.opacity(0.25))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 24)
                #else
                Color.clear.frame(height: 24)
                #endif
            }

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .frame(width: 30, height: 30)
                    .background(Circle().strokeBorder(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
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
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 52)
    }

    private func settingsRow(icon: String, label: String, tint: Color = .nommieBrown, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(tint.opacity(0.7))
                    .frame(width: 22)
                Text(label)
                    .font(Font.custom("Nunito-SemiBold", size: 15))
                    .foregroundColor(tint == .nommieBlush ? .nommieBlush : .nommieBrown)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.nommieBrown.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
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
    // Posted only when a recipe was edited — open detail views dismiss so the
    // parent list can show fresh data. profileNeedsRefresh is too broad for
    // that job (saves and follows post it too).
    static let recipeEdited = Notification.Name("recipeEdited")
    // Posted with the new Recipe when a user saves their first-ever plate.
    static let firstPlateCreated = Notification.Name("firstPlateCreated")
    // Debug: replay the first-plate flow using the user's most recent plate.
    static let replayFirstPlateFlow = Notification.Name("replayFirstPlateFlow")
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
                                let isSelf = user.id == authViewModel.currentNommieUser?.id
                                Button(action: {
                                    if !isSelf { selectedUsername = user.username }
                                }) {
                                    HStack(spacing: 12) {
                                        AvatarView(
                                            userId: user.id,
                                            username: user.username,
                                            photoURL: user.photoURL,
                                            size: 40
                                        )
                                        Text("@\(user.username)")
                                            .font(Font.custom("Nunito-SemiBold", size: 16))
                                            .foregroundColor(.nommieBrown)
                                        if isSelf {
                                            Text("you")
                                                .font(Font.custom("Nunito-Regular", size: 12))
                                                .foregroundColor(.nommieBrown.opacity(0.4))
                                        }
                                        Spacer()
                                        if !isSelf {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13))
                                                .foregroundColor(.nommieBrown.opacity(0.3))
                                        }
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

// Identity must be the value itself: a fresh UUID per render makes SwiftUI
// think the item changed and dismiss whatever it's presenting.
private struct FollowIdentifiable: Identifiable {
    let value: String
    var id: String { value }
}

#Preview {
    ProfileView().environmentObject(AuthViewModel())
}
