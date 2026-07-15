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
    @State private var followingActorIds: Set<String> = []
    @State private var followLoadingIds: Set<String> = []

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
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(sections) { section in
                                Section {
                                    ForEach(section.rows) { row in
                                        rowView(row)
                                        Divider().padding(.leading, 70)
                                    }
                                } header: {
                                    HStack {
                                        Text(section.title)
                                            .font(Font.custom("Nunito-Bold", size: 12))
                                            .foregroundColor(.nommieBrown.opacity(0.5))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(Color.nommieBackground)
                                }
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
        .task { await loadFollowingState() }
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

    // MARK: - Sections + like grouping

    // Groups a recipe's likes into one row once there are 5+, then buckets
    // everything by recency.
    private var sections: [NotifSection] {
        var likeGroups: [String: [AppNotification]] = [:]
        var rows: [NotifRow] = []
        for n in notificationsVM.notifications {
            if n.kind == .like, let rid = n.recipeId {
                likeGroups[rid, default: []].append(n)
            } else {
                rows.append(.single(n))
            }
        }
        for (rid, items) in likeGroups {
            if items.count >= 5 {
                rows.append(.likeGroup(id: "lg_\(rid)", recipeId: rid, dishName: items.first?.dishName, items: items))
            } else {
                rows.append(contentsOf: items.map { NotifRow.single($0) })
            }
        }
        rows.sort { $0.sortDate > $1.sortDate }

        let now = Date()
        let titles = ["Past 24 hours", "Past week", "Past month", "Older"]
        var buckets: [[NotifRow]] = [[], [], [], []]
        for row in rows {
            let dt = now.timeIntervalSince(row.sortDate)
            let b = dt < 86_400 ? 0 : (dt < 604_800 ? 1 : (dt < 2_592_000 ? 2 : 3))
            buckets[b].append(row)
        }
        return (0..<4).compactMap { i in
            buckets[i].isEmpty ? nil : NotifSection(title: titles[i], rows: buckets[i])
        }
    }

    @ViewBuilder
    private func rowView(_ row: NotifRow) -> some View {
        switch row {
        case .single(let n):
            singleRow(n)
        case .likeGroup(_, let recipeId, let dishName, let items):
            likeGroupRow(recipeId: recipeId, dishName: dishName, items: items)
        }
    }

    private func iconBadge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 17, height: 17)
            .background(Circle().fill(Color.nommieGreen))
    }

    private var unreadDot: some View {
        Circle().fill(Color.nommieGreen).frame(width: 8, height: 8).padding(.top, 6)
    }

    @ViewBuilder
    private func singleRow(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { openProfile(notification.actorUsername) }) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(
                        userId: notification.actorId,
                        username: notification.actorUsername,
                        photoURL: notificationsVM.actorPhotoById[notification.actorId],
                        size: 40
                    )
                    iconBadge(notification.iconName).offset(x: 4, y: 3)
                }
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(attributedMessage(notification))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { url in handleLink(url); return .handled })
                Text(notification.createdAt.nommieRelative)
                    .font(Font.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.nommieBrown.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if notification.kind == .follow {
                followBackButton(for: notification)
            } else if !notification.read {
                unreadDot
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func likeGroupRow(recipeId: String?, dishName: String?, items: [AppNotification]) -> some View {
        let anyUnread = items.contains { !$0.read }
        HStack(alignment: .top, spacing: 12) {
            Button(action: { openProfile(items.first?.actorUsername ?? "") }) {
                ZStack(alignment: .bottomTrailing) {
                    // Two overlapping avatars
                    if items.count > 1 {
                        AvatarView(
                            userId: items[1].actorId, username: items[1].actorUsername,
                            photoURL: notificationsVM.actorPhotoById[items[1].actorId], size: 30
                        )
                        .overlay(Circle().stroke(Color.nommieBackground, lineWidth: 2))
                        .offset(x: 14, y: 0)
                    }
                    AvatarView(
                        userId: items[0].actorId, username: items[0].actorUsername,
                        photoURL: notificationsVM.actorPhotoById[items[0].actorId], size: 34
                    )
                    .overlay(Circle().stroke(Color.nommieBackground, lineWidth: 2))
                    iconBadge("heart.fill").offset(x: 18, y: 4)
                }
                .frame(width: 48, height: 40, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(likeGroupMessage(items: items, dish: dishName, recipeId: recipeId))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { url in handleLink(url); return .handled })
                Text((items.map { $0.createdAt }.max() ?? Date()).nommieRelative)
                    .font(Font.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.nommieBrown.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if anyUnread { unreadDot }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    private func likeGroupMessage(items: [AppNotification], dish: String?, recipeId: String?) -> AttributedString {
        let others = items.count - 1
        let bold = Font.custom("Nunito-Bold", size: 14)
        let semi = Font.custom("Nunito-SemiBold", size: 14)
        let brown = Color.nommieBrown

        var name = AttributedString("@\(items.first?.actorUsername ?? "someone")")
        name.font = bold; name.foregroundColor = brown
        name.link = URL(string: "nommie://user/\(items.first?.actorUsername ?? "")")

        var mid = AttributedString(others > 0 ? " and \(others) \(others == 1 ? "other" : "others") liked " : " liked ")
        mid.font = semi; mid.foregroundColor = brown

        var dishPart = AttributedString(dish ?? "your recipe")
        if let recipeId {
            dishPart.font = bold; dishPart.foregroundColor = .nommieGreen
            dishPart.link = URL(string: "nommie://recipe/\(recipeId)")
        } else {
            dishPart.font = semi; dishPart.foregroundColor = brown
        }
        return name + mid + dishPart
    }

    // MARK: - Message with tappable segments
    // Usernames link to profiles; the dish name links to the recipe. Rendered
    // through AttributedString links so taps land exactly on the words.

    private func attributedMessage(_ n: AppNotification) -> AttributedString {
        let baseColor = Color.nommieBrown.opacity(n.read ? 0.7 : 1.0)
        let baseFont = Font.custom(n.read ? "Nunito-Regular" : "Nunito-SemiBold", size: 14)

        func plain(_ s: String) -> AttributedString {
            var a = AttributedString(s)
            a.font = baseFont
            a.foregroundColor = baseColor
            return a
        }
        func user(_ name: String) -> AttributedString {
            var a = AttributedString("@\(name)")
            a.font = Font.custom("Nunito-Bold", size: 14)
            a.foregroundColor = baseColor
            a.link = URL(string: "nommie://user/\(name)")
            return a
        }
        func dishLink(_ label: String) -> AttributedString {
            guard let id = n.recipeId else { return plain(label) }
            var a = AttributedString(label)
            a.font = Font.custom("Nunito-Bold", size: 14)
            a.foregroundColor = Color.nommieGreen
            a.link = URL(string: "nommie://recipe/\(id)")
            return a
        }
        func quoted(_ preview: String?) -> AttributedString {
            guard let preview, !preview.isEmpty else { return AttributedString() }
            return plain(": \u{201C}\(preview)\u{201D}")
        }

        let dish = n.dishName ?? "your recipe"
        switch n.kind {
        case .follow:
            return user(n.actorUsername) + plain(" started following you")
        case .like:
            return user(n.actorUsername) + plain(" liked your ") + dishLink(dish)
        case .save:
            return user(n.actorUsername) + plain(" saved your ") + dishLink(dish)
        case .comment:
            return user(n.actorUsername) + plain(" on your ") + dishLink(dish) + quoted(n.preview)
        case .reply:
            return user(n.actorUsername) + plain(" replied to your comment on ") + dishLink(dish) + quoted(n.preview)
        case .replate:
            return user(n.actorUsername) + plain(" cooked your ") + dishLink(dish)
        case .friendLike:
            return user(n.actorUsername) + plain(" liked ") + user(n.targetUsername ?? "someone") + plain("'s ") + dishLink(dish)
        case .friendComment:
            return user(n.actorUsername) + plain(" commented on ") + user(n.targetUsername ?? "someone") + plain("'s ") + dishLink(dish) + quoted(n.preview)
        case .newRecipe:
            return user(n.actorUsername) + plain(" plated something new: ") + dishLink(dish)
        case .mention:
            return user(n.actorUsername) + plain(" mentioned you in ") + dishLink(dish)
        case .commentLike:
            return user(n.actorUsername) + plain(" liked your comment") + quoted(n.preview)
        }
    }

    private func handleLink(_ url: URL) {
        guard url.scheme == "nommie" else { return }
        let value = url.pathComponents.count > 1 ? url.pathComponents[1] : ""
        switch url.host {
        case "user":
            openProfile(value)
        case "recipe":
            guard !value.isEmpty else { return }
            Task {
                if let recipe = try? await userService.fetchRecipe(id: value) {
                    await MainActor.run { openedRecipe = recipe }
                }
            }
        default:
            break
        }
    }

    private func openProfile(_ username: String) {
        guard !username.isEmpty, username != authViewModel.currentNommieUser?.username else { return }
        profileUsername = NotifProfileUsername(value: username)
    }

    // MARK: - Follow back

    @ViewBuilder
    private func followBackButton(for n: AppNotification) -> some View {
        // Can't follow yourself; a self-follow notification shouldn't happen,
        // but guard anyway.
        if n.actorId != authViewModel.currentNommieUser?.id {
            let isFollowing = followingActorIds.contains(n.actorId)
            Button(action: { toggleFollow(n) }) {
                Group {
                    if followLoadingIds.contains(n.actorId) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: isFollowing ? .nommieGreen : .white))
                            .scaleEffect(0.7)
                    } else {
                        Text(isFollowing ? "Following" : "Follow back")
                            .font(Font.custom("Nunito-SemiBold", size: 12))
                    }
                }
                .foregroundColor(isFollowing ? .nommieGreen : .white)
                .frame(width: 92, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(isFollowing ? Color.clear : Color.nommieGreen)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.nommieGreen, lineWidth: 1.3))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func loadFollowingState() async {
        guard let uid = authViewModel.currentNommieUser?.id else { return }
        let following = (try? await userService.fetchFollowing(userId: uid)) ?? []
        await MainActor.run { followingActorIds = Set(following.map { $0.id }) }
    }

    private func toggleFollow(_ n: AppNotification) {
        guard let uid = authViewModel.currentNommieUser?.id,
              let username = authViewModel.currentNommieUser?.username,
              !followLoadingIds.contains(n.actorId) else { return }

        let wasFollowing = followingActorIds.contains(n.actorId)
        followLoadingIds.insert(n.actorId)
        Task {
            do {
                if wasFollowing {
                    try await userService.unfollowUser(followerId: uid, followingId: n.actorId)
                    await MainActor.run { followingActorIds.remove(n.actorId) }
                } else {
                    try await userService.followUser(followerId: uid, followingId: n.actorId)
                    await MainActor.run {
                        followingActorIds.insert(n.actorId)
                        NommieAnalytics.followTapped()
                    }
                }
            } catch {}
            await MainActor.run { followLoadingIds.remove(n.actorId) }
        }
    }
}

// Identity must be the value itself — see the presentation-dismissal bug notes.
private struct NotifProfileUsername: Identifiable {
    let value: String
    var id: String { value }
}

// A row is either one notification or a collapsed group of likes on a recipe.
private enum NotifRow: Identifiable {
    case single(AppNotification)
    case likeGroup(id: String, recipeId: String?, dishName: String?, items: [AppNotification])

    var id: String {
        switch self {
        case .single(let n): return n.id
        case .likeGroup(let id, _, _, _): return id
        }
    }
    var sortDate: Date {
        switch self {
        case .single(let n): return n.createdAt
        case .likeGroup(_, _, _, let items): return items.map { $0.createdAt }.max() ?? .distantPast
        }
    }
}

private struct NotifSection: Identifiable {
    let title: String
    let rows: [NotifRow]
    var id: String { title }
}
