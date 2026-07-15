import SwiftUI
import Combine
import FirebaseFirestore

// Live activity feed: one snapshot listener per session keeps the bell badge
// current and surfaces an in-app toast when something new arrives while the
// app is open. Docs are trigger-written; we only read/mark/delete.
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var toast: AppNotification? = nil
    @Published var actorPhotoById: [String: String] = [:]

    private var listener: ListenerRegistration? = nil
    private var listeningForUserId: String? = nil
    private var hasReceivedInitialSnapshot = false
    private var toastDismissTask: Task<Void, Never>? = nil
    private let activityService = ActivityService()
    private let userService = UserService()

    func startListening(userId: String) {
        guard listeningForUserId != userId else { return }
        stopListening()
        listeningForUserId = userId
        hasReceivedInitialSnapshot = false

        listener = Firestore.firestore().collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }

                let items = snapshot.documents
                    .compactMap { AppNotification(id: $0.documentID, from: $0.data()) }
                    .sorted { $0.createdAt > $1.createdAt }

                // Toast only genuinely-new arrivals, never the initial load
                if self.hasReceivedInitialSnapshot {
                    let fresh = snapshot.documentChanges
                        .filter { $0.type == .added }
                        .compactMap { AppNotification(id: $0.document.documentID, from: $0.document.data()) }
                    if let newest = fresh.max(by: { $0.createdAt < $1.createdAt }) {
                        self.showToast(newest)
                    }
                }
                self.hasReceivedInitialSnapshot = true

                self.notifications = items
                self.unreadCount = items.filter { !$0.read }.count
                self.hydrateActorPhotos(for: items)
            }
    }

    // Fetch profile photos for any actors we haven't resolved yet, so
    // notification rows show real avatars instead of initials.
    private func hydrateActorPhotos(for items: [AppNotification]) {
        let missing = Set(items.map { $0.actorId }).subtracting(actorPhotoById.keys)
        guard !missing.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            let userMap = (try? await self.userService.fetchUserMap(ids: Array(missing))) ?? [:]
            await MainActor.run {
                for (id, user) in userMap {
                    self.actorPhotoById[id] = user.photoURL
                }
                // Mark unresolved ids with an empty string so we don't refetch
                for id in missing where self.actorPhotoById[id] == nil {
                    self.actorPhotoById[id] = ""
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        listeningForUserId = nil
        notifications = []
        unreadCount = 0
    }

    func markAllRead() {
        guard let userId = listeningForUserId else { return }
        // Optimistic — the listener will confirm
        unreadCount = 0
        let toMark = notifications
        Task { await activityService.markAllRead(recipientId: userId, notifications: toMark) }
    }

    private func showToast(_ notification: AppNotification) {
        toastDismissTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            toast = notification
        }
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { self?.toast = nil }
            }
        }
    }

    func dismissToast() {
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { toast = nil }
    }

    deinit {
        listener?.remove()
    }
}
