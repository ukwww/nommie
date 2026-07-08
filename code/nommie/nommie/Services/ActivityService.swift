import Foundation
import FirebaseFirestore

// Comments + in-app notifications. Notification docs are created only by
// cloud triggers; the client reads, marks read, and deletes.
class ActivityService {
    private let db = Firestore.firestore()

    // MARK: - Comments

    func postComment(recipe: Recipe, userId: String, username: String, text: String, parentCommentId: String? = nil) async throws -> Comment {
        let comment = Comment(
            recipeId: recipe.id,
            recipeOwnerId: recipe.userId,
            userId: userId,
            username: username,
            text: String(text.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines),
            parentCommentId: parentCommentId
        )
        try await db.collection("comments").document(comment.id).setData(comment.toDictionary())
        return comment
    }

    func setCommentLiked(commentId: String, userId: String, liked: Bool) async throws {
        let ref = db.collection("comments").document(commentId)
        if liked {
            try await ref.updateData(["likedBy": FieldValue.arrayUnion([userId])])
        } else {
            try await ref.updateData(["likedBy": FieldValue.arrayRemove([userId])])
        }
    }

    func fetchComments(recipeId: String) async throws -> [Comment] {
        // No order(by:) to avoid a composite index; sort client-side.
        let snap = try await db.collection("comments")
            .whereField("recipeId", isEqualTo: recipeId)
            .getDocuments()
        return snap.documents
            .compactMap { Comment(id: $0.documentID, from: $0.data()) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func deleteComment(commentId: String) async throws {
        try await db.collection("comments").document(commentId).delete()
    }

    func reportComment(comment: Comment, reporterId: String, reason: String) async throws {
        try await db.collection("reports").addDocument(data: [
            "contentType": "comment",
            "commentId": comment.id,
            "commentText": comment.text,
            "recipeId": comment.recipeId,
            "recipeOwnerId": comment.recipeOwnerId,
            "reportedUserId": comment.userId,
            "reporterId": reporterId,
            "reason": reason,
            "createdAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Notifications

    func markAllRead(recipientId: String, notifications: [AppNotification]) async {
        let unread = notifications.filter { !$0.read }
        guard !unread.isEmpty else { return }
        let batch = db.batch()
        for notification in unread {
            batch.updateData(["read": true], forDocument: db.collection("notifications").document(notification.id))
        }
        try? await batch.commit()
    }

    func deleteAllNotifications(recipientId: String) async {
        let snap = try? await db.collection("notifications")
            .whereField("recipientId", isEqualTo: recipientId)
            .getDocuments()
        guard let docs = snap?.documents, !docs.isEmpty else { return }
        let batch = db.batch()
        docs.forEach { batch.deleteDocument($0.reference) }
        try? await batch.commit()
    }
}
