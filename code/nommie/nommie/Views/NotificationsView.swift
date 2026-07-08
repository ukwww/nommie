import SwiftUI

// The bell sheet: every follow, like, save, comment, and replate, newest
// first. Opening it marks everything read. Rows navigate to the recipe or
// the actor's profile.
struct NotificationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationsVM: NotificationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var openedRecipe: Recipe? = nil
    @State private var profileUsername: NotifProfileUsername? = nil

    private let userService = UserService()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Activity")
                    .font(Font.custom("Lora-SemiBold", size: 20))
                    .foregroundColor(.nommieBrown)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                if notificationsVM.notifications.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bell")
                            .font(.system(size: 36))
                            .foregroundColor(.nommieGreen.opacity(0.3))
                        Text("Nothing yet")
                            .font(Font.custom("Nunito-SemiBold", size: 15))
                            .foregroundColor(.nommieBrown.opacity(0.5))
                        Text("Follows, likes, saves, comments, and\nreplates will show up here.")
                            .font(Font.custom("Nunito-Regular", size: 13))
                            .foregroundColor(.nommieBrown.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(notificationsVM.notifications) { notification in
                                Button(action: { open(notification) }) {
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack(alignment: .bottomTrailing) {
                                            AvatarView(
                                                userId: notification.actorId,
                                                username: notification.actorUsername,
                                                size: 40
                                            )
                                            Image(systemName: notification.iconName)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 17, height: 17)
                                                .background(Circle().fill(Color.nommieGreen))
                                                .offset(x: 4, y: 3)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(notification.message)
                                                .font(Font.custom(notification.read ? "Nunito-Regular" : "Nunito-SemiBold", size: 14))
                                                .foregroundColor(.nommieBrown.opacity(notification.read ? 0.7 : 1.0))
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(notification.createdAt.nommieRelative)
                                                .font(Font.custom("Nunito-Regular", size: 11))
                                                .foregroundColor(.nommieBrown.opacity(0.4))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        if !notification.read {
                                            Circle()
                                                .fill(Color.nommieGreen)
                                                .frame(width: 8, height: 8)
                                                .padding(.top, 6)
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 11)
                                }
                                .buttonStyle(PlainButtonStyle())
                                Divider().padding(.leading, 70)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }

            // X button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .frame(width: 30, height: 30)
                    .background(Circle().strokeBorder(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear { notificationsVM.markAllRead() }
        .sheet(item: $openedRecipe) { recipe in
            RecipeDetailView(
                recipe: recipe,
                isOwner: recipe.userId == authViewModel.currentNommieUser?.id
            )
            .environmentObject(authViewModel)
        }
        .fullScreenCover(item: $profileUsername) { wrapper in
            OtherUserProfileView(username: wrapper.value)
                .environmentObject(authViewModel)
        }
    }

    private func open(_ notification: AppNotification) {
        switch notification.kind {
        case .follow:
            profileUsername = NotifProfileUsername(value: notification.actorUsername)
        case .like, .save, .comment, .replate, .reply:
            guard let recipeId = notification.recipeId else {
                profileUsername = NotifProfileUsername(value: notification.actorUsername)
                return
            }
            Task {
                if let recipe = try? await userService.fetchRecipe(id: recipeId) {
                    await MainActor.run { openedRecipe = recipe }
                }
            }
        }
    }
}

// Identity must be the value itself — see the presentation-dismissal bug notes.
private struct NotifProfileUsername: Identifiable {
    let value: String
    var id: String { value }
}
