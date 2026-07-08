import Foundation
import FirebaseFirestore

// MARK: - Comment

struct Comment: Identifiable, Codable {
    var id: String
    var recipeId: String
    var recipeOwnerId: String
    var userId: String
    var username: String
    var text: String
    var likedBy: [String]
    // One-level threading: replies carry their parent's id; replies to a
    // reply attach to the same parent.
    var parentCommentId: String?
    var createdAt: Date

    var isReply: Bool { parentCommentId != nil }
    var likeCount: Int { likedBy.count }
    var likedByCreator: Bool { !recipeOwnerId.isEmpty && likedBy.contains(recipeOwnerId) }

    init(id: String = UUID().uuidString, recipeId: String, recipeOwnerId: String, userId: String, username: String, text: String, likedBy: [String] = [], parentCommentId: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.recipeId = recipeId
        self.recipeOwnerId = recipeOwnerId
        self.userId = userId
        self.username = username
        self.text = text
        self.likedBy = likedBy
        self.parentCommentId = parentCommentId
        self.createdAt = createdAt
    }

    init?(id: String, from dictionary: [String: Any]) {
        guard
            let recipeId = dictionary["recipeId"] as? String,
            let userId = dictionary["userId"] as? String,
            let text = dictionary["text"] as? String
        else { return nil }

        self.id = id
        self.recipeId = recipeId
        self.recipeOwnerId = dictionary["recipeOwnerId"] as? String ?? ""
        self.userId = userId
        self.username = dictionary["username"] as? String ?? ""
        self.text = text
        self.likedBy = dictionary["likedBy"] as? [String] ?? []
        self.parentCommentId = dictionary["parentCommentId"] as? String
        self.createdAt = (dictionary["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "recipeId": recipeId,
            "recipeOwnerId": recipeOwnerId,
            "userId": userId,
            "username": username,
            "text": text,
            "likedBy": likedBy,
            "createdAt": Timestamp(date: createdAt)
        ]
        if let parentCommentId {
            dict["parentCommentId"] = parentCommentId
        }
        return dict
    }
}

// MARK: - App Notification (in-app activity feed)

struct AppNotification: Identifiable, Codable {
    enum Kind: String {
        case follow, like, save, comment, replate, reply
    }

    var id: String
    var recipientId: String
    var type: String
    var actorId: String
    var actorUsername: String
    var recipeId: String?
    var dishName: String?
    var preview: String?
    var read: Bool
    var createdAt: Date

    var kind: Kind { Kind(rawValue: type) ?? .like }

    init?(id: String, from dictionary: [String: Any]) {
        guard
            let recipientId = dictionary["recipientId"] as? String,
            let type = dictionary["type"] as? String,
            let actorId = dictionary["actorId"] as? String
        else { return nil }

        self.id = id
        self.recipientId = recipientId
        self.type = type
        self.actorId = actorId
        self.actorUsername = dictionary["actorUsername"] as? String ?? ""
        self.recipeId = dictionary["recipeId"] as? String
        self.dishName = dictionary["dishName"] as? String
        self.preview = dictionary["preview"] as? String
        self.read = dictionary["read"] as? Bool ?? false
        self.createdAt = (dictionary["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    // "@sam liked your Chicken Juk"
    var message: String {
        let name = "@\(actorUsername)"
        let dish = dishName ?? "your recipe"
        switch kind {
        case .follow:  return "\(name) started following you"
        case .like:    return "\(name) liked your \(dish)"
        case .save:    return "\(name) saved your \(dish)"
        case .replate: return "\(name) cooked your \(dish)"
        case .comment:
            if let preview, !preview.isEmpty {
                return "\(name) on your \(dish): \u{201C}\(preview)\u{201D}"
            }
            return "\(name) commented on your \(dish)"
        case .reply:
            if let preview, !preview.isEmpty {
                return "\(name) replied to your comment: \u{201C}\(preview)\u{201D}"
            }
            return "\(name) replied to your comment"
        }
    }

    var iconName: String {
        switch kind {
        case .follow:  return "person.badge.plus"
        case .like:    return "heart.fill"
        case .save:    return "bookmark.fill"
        case .comment: return "bubble.left.fill"
        case .replate: return "arrow.2.squarepath"
        case .reply:   return "arrowshape.turn.up.left.fill"
        }
    }
}
