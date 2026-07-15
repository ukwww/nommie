import SwiftUI

// Comments on a recipe — one-level threading (replies indent under their
// parent), comment likes with a "Liked by creator" marker, composer pinned
// above the keyboard. The comment author and the recipe owner can delete;
// anyone can report; blocked users' comments never render.
struct CommentsView: View {
    let recipe: Recipe
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [Comment] = []
    @State private var authorPhotos: [String: String] = [:]
    @State private var isLoading = true
    @State private var draft: String = ""
    @State private var isPosting = false
    @State private var replyingTo: Comment? = nil
    @State private var blockedIds: Set<String> = []
    @State private var reportTarget: Comment? = nil
    @State private var showingReportThanks = false
    @State private var profileUsername: CommentProfileUsername? = nil
    @FocusState private var composerFocused: Bool

    private let activityService = ActivityService()
    private let userService = UserService()

    private var visibleComments: [Comment] {
        comments.filter { !blockedIds.contains($0.userId) }
    }

    private var parentComments: [Comment] {
        visibleComments.filter { !$0.isReply }
    }

    private func replies(to parent: Comment) -> [Comment] {
        visibleComments.filter { $0.parentCommentId == parent.id }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Comments")
                    .font(Font.custom("Lora-SemiBold", size: 20))
                    .foregroundColor(.nommieBrown)
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                if isLoading {
                    Spacer()
                    NommieSpinningLogo(size: 32)
                    Spacer()
                } else if visibleComments.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 36))
                            .foregroundColor(.nommieGreen.opacity(0.3))
                        Text("No comments yet")
                            .font(Font.custom("Nunito-SemiBold", size: 15))
                            .foregroundColor(.nommieBrown.opacity(0.5))
                        Text("Say something nice about this plate.")
                            .font(Font.custom("Nunito-Regular", size: 13))
                            .foregroundColor(.nommieBrown.opacity(0.4))
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(parentComments) { parent in
                                    commentRow(parent, indented: false)
                                        .id(parent.id)
                                    ForEach(replies(to: parent)) { reply in
                                        commentRow(reply, indented: true)
                                            .id(reply.id)
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 12)
                        }
                        .onChange(of: visibleComments.count) { _, _ in
                            if let last = comments.last {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                // Replying-to banner
                if let replyingTo {
                    HStack(spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: 11))
                        Text("Replying to @\(replyingTo.username)")
                            .font(Font.custom("Nunito-Regular", size: 12))
                        Spacer()
                        Button(action: { self.replyingTo = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                        }
                    }
                    .foregroundColor(.nommieBrown.opacity(0.55))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 7)
                    .background(Color.nommieBrown.opacity(0.06))
                }

                // Composer
                HStack(spacing: 10) {
                    AvatarView(
                        userId: authViewModel.currentNommieUser?.id ?? "",
                        username: authViewModel.currentNommieUser?.username ?? "",
                        photoURL: authViewModel.currentNommieUser?.photoURL,
                        size: 32
                    )

                    TextField("", text: $draft, prompt: Text(replyingTo == nil ? "Add a comment..." : "Add a reply...").foregroundColor(.nommieBrown.opacity(0.4)), axis: .vertical)
                        .font(Font.custom("Nunito-Regular", size: 15))
                        .foregroundColor(.nommieBrown)
                        .lineLimit(1...4)
                        .focused($composerFocused)
                        .onChange(of: draft) { _, newValue in
                            if newValue.count > 500 { draft = String(newValue.prefix(500)) }
                        }

                    Button(action: post) {
                        if isPosting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .nommieGreen))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(canPost ? .nommieGreen : .nommieBrown.opacity(0.2))
                        }
                    }
                    .disabled(!canPost || isPosting)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.nommieBrown.opacity(0.12), lineWidth: 1))
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .task { await load() }
        .confirmationDialog("Report this comment", isPresented: Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        ), titleVisibility: .visible) {
            Button("Inappropriate or offensive") { submitReport(reason: "inappropriate") }
            Button("Spam") { submitReport(reason: "spam") }
            Button("Cancel", role: .cancel) { reportTarget = nil }
        }
        .alert("Thanks for the report", isPresented: $showingReportThanks) {
            Button("OK") {}
        } message: {
            Text("We'll review this comment within 24 hours.")
        }
        .fullScreenCover(item: $profileUsername) { wrapper in
            OtherUserProfileView(username: wrapper.value)
                .environmentObject(authViewModel)
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: Comment, indented: Bool) -> some View {
        CommentRow(
            comment: comment,
            indented: indented,
            photoURL: authorPhotos[comment.userId],
            likedByMe: comment.likedBy.contains(authViewModel.currentNommieUser?.id ?? ""),
            canDelete: canDelete(comment),
            onLike: { toggleLike(comment) },
            onReply: {
                replyingTo = comment
                composerFocused = true
            },
            onDelete: { delete(comment) },
            onReport: { reportTarget = comment },
            onProfileTap: {
                if comment.username != authViewModel.currentNommieUser?.username {
                    profileUsername = CommentProfileUsername(value: comment.username)
                }
            },
            onMentionTap: { handle in
                if !handle.isEmpty, handle != authViewModel.currentNommieUser?.username {
                    profileUsername = CommentProfileUsername(value: handle)
                }
            }
        )
    }

    private var canPost: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func canDelete(_ comment: Comment) -> Bool {
        guard let uid = authViewModel.currentNommieUser?.id else { return false }
        return comment.userId == uid || recipe.userId == uid
    }

    private func load() async {
        if let uid = authViewModel.currentNommieUser?.id {
            blockedIds = (try? await userService.fetchBlockedUserIds(blockerId: uid)) ?? []
        }
        let fetched = (try? await activityService.fetchComments(recipeId: recipe.id)) ?? []
        await MainActor.run {
            comments = fetched
            isLoading = false
        }
        await hydratePhotos(for: fetched.map { $0.userId })
    }

    // Resolve commenter profile photos so their avatars show real pictures.
    private func hydratePhotos(for userIds: [String]) async {
        let missing = Set(userIds).subtracting(authorPhotos.keys)
        guard !missing.isEmpty else { return }
        let userMap = (try? await userService.fetchUserMap(ids: Array(missing))) ?? [:]
        await MainActor.run {
            for id in missing {
                authorPhotos[id] = userMap[id]?.photoURL ?? ""
            }
        }
    }

    private func post() {
        guard let user = authViewModel.currentNommieUser, canPost else { return }
        let text = draft
        // Replies to a reply flatten under the original parent
        let parentId = replyingTo.map { $0.parentCommentId ?? $0.id }
        isPosting = true
        Task {
            do {
                let posted = try await activityService.postComment(
                    recipe: recipe, userId: user.id, username: user.username,
                    text: text, parentCommentId: parentId
                )
                await MainActor.run {
                    authorPhotos[user.id] = user.photoURL
                    comments.append(posted)
                    draft = ""
                    replyingTo = nil
                    isPosting = false
                    NommieAnalytics.commentPosted()
                }
            } catch {
                await MainActor.run { isPosting = false }
            }
        }
    }

    private func toggleLike(_ comment: Comment) {
        guard let uid = authViewModel.currentNommieUser?.id,
              let idx = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        let nowLiked = !comments[idx].likedBy.contains(uid)
        if nowLiked {
            comments[idx].likedBy.append(uid)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            comments[idx].likedBy.removeAll { $0 == uid }
        }
        Task { try? await activityService.setCommentLiked(commentId: comment.id, userId: uid, liked: nowLiked) }
    }

    private func delete(_ comment: Comment) {
        // Deleting a parent also hides its replies locally; the docs remain
        // but never render without their parent, and counts self-correct.
        comments.removeAll { $0.id == comment.id || $0.parentCommentId == comment.id }
        Task { try? await activityService.deleteComment(commentId: comment.id) }
    }

    private func submitReport(reason: String) {
        guard let target = reportTarget, let uid = authViewModel.currentNommieUser?.id else { return }
        reportTarget = nil
        Task {
            try? await activityService.reportComment(comment: target, reporterId: uid, reason: reason)
            await MainActor.run { showingReportThanks = true }
        }
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: Comment
    let indented: Bool
    let photoURL: String?
    let likedByMe: Bool
    let canDelete: Bool
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onProfileTap: () -> Void
    let onMentionTap: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onProfileTap) {
                AvatarView(userId: comment.userId, username: comment.username, photoURL: photoURL, size: indented ? 26 : 34)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Button(action: onProfileTap) {
                        Text("@\(comment.username)")
                            .font(Font.custom("Nunito-Bold", size: 13))
                            .foregroundColor(.nommieBrown)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Text(comment.createdAt.nommieRelative)
                        .font(Font.custom("Nunito-Regular", size: 11))
                        .foregroundColor(.nommieBrown.opacity(0.4))
                }

                Text(mentionAttributed(comment.text))
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { url in
                        if url.scheme == "nommie", url.host == "user" {
                            let handle = url.pathComponents.count > 1 ? url.pathComponents[1] : ""
                            onMentionTap(handle)
                        }
                        return .handled
                    })

                HStack(spacing: 12) {
                    Button(action: onReply) {
                        Text("Reply")
                            .font(Font.custom("Nunito-SemiBold", size: 11))
                            .foregroundColor(.nommieBrown.opacity(0.45))
                    }
                    .buttonStyle(PlainButtonStyle())

                    if comment.likedByCreator {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                            Text("Liked by creator")
                                .font(Font.custom("Nunito-Regular", size: 11))
                        }
                        .foregroundColor(.nommieGreen)
                    }
                }
                .padding(.top, 1)
            }

            Spacer()

            // Trailing: overflow menu, then a heart with its count directly beneath.
            HStack(alignment: .top, spacing: 8) {
                Menu {
                    if canDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    Button(action: onReport) {
                        Label("Report", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(.nommieBrown.opacity(0.3))
                        .frame(width: 22, height: 22)
                }

                VStack(spacing: 2) {
                    Button(action: onLike) {
                        Image(systemName: likedByMe ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(likedByMe ? .nommieBlush : .nommieBrown.opacity(0.35))
                    }
                    .buttonStyle(PlainButtonStyle())
                    if comment.likeCount > 0 {
                        Text("\(comment.likeCount)")
                            .font(Font.custom("Nunito-SemiBold", size: 11))
                            .foregroundColor(.nommieBrown.opacity(0.45))
                    }
                }
            }
        }
        .padding(.leading, indented ? 52 : 18)
        .padding(.trailing, 18)
        .padding(.vertical, 9)
    }

    // Renders comment text with @username mentions as tappable green links.
    private func mentionAttributed(_ text: String) -> AttributedString {
        let baseFont = Font.custom("Nunito-Regular", size: 14)
        let baseColor = Color.nommieBrown.opacity(0.85)

        var out = AttributedString()
        let ns = text as NSString
        let regex = try? NSRegularExpression(pattern: "@([A-Za-z0-9_]+)")
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: ns.length)) ?? []

        var cursor = 0
        for m in matches {
            if m.range.location > cursor {
                var seg = AttributedString(ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor)))
                seg.font = baseFont; seg.foregroundColor = baseColor
                out += seg
            }
            let handle = ns.substring(with: m.range(at: 1))
            var mention = AttributedString(ns.substring(with: m.range))
            mention.font = Font.custom("Nunito-Bold", size: 14)
            mention.foregroundColor = .nommieGreen
            mention.link = URL(string: "nommie://user/\(handle)")
            out += mention
            cursor = m.range.location + m.range.length
        }
        if cursor < ns.length {
            var seg = AttributedString(ns.substring(from: cursor))
            seg.font = baseFont; seg.foregroundColor = baseColor
            out += seg
        }
        return out
    }
}

// Identity must be the value itself — see the presentation-dismissal bug notes.
private struct CommentProfileUsername: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Relative time ("2h", "3d")

extension Date {
    var nommieRelative: String {
        let seconds = Int(Date().timeIntervalSince(self))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        if seconds < 604800 { return "\(seconds / 86400)d" }
        return "\(seconds / 604800)w"
    }
}
