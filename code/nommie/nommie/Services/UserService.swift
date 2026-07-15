import Foundation
import FirebaseFirestore
import Combine

class UserService {
    private let db = Firestore.firestore()

    // MARK: - Profile

    func createUserProfile(uid: String, username: String, email: String) async throws {
        let data: [String: Any] = [
            "uid": uid,
            "username": username,
            "email": email,
            "createdAt": Timestamp(date: Date())
        ]
        try await db.collection("users").document(uid).setData(data)
    }

    func fetchUserProfile(uid: String) async throws -> [String: Any]? {
        let document = try await db.collection("users").document(uid).getDocument()
        return document.data()
    }

    func fetchUserProfileByUsername(_ username: String) async throws -> NommieUser? {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
        guard let doc = snapshot.documents.first else { return nil }
        return NommieUser(from: doc.data())
    }

    func searchUsers(prefix: String) async throws -> [NommieUser] {
        let lower = prefix.lowercased()
        guard !lower.isEmpty else { return [] }
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: lower)
            .whereField("username", isLessThan: lower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()
        return snapshot.documents.compactMap { NommieUser(from: $0.data()) }
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        return snapshot.documents.isEmpty
    }

    // MARK: - Recipes

    func deleteRecipe(recipeId: String) async throws {
        let imageService = ImageUploadService()
        try? await imageService.deleteImage(recipeId: recipeId)
        try await db.collection("recipes").document(recipeId).delete()
    }

    func deleteAllUserData(uid: String) async throws {
        let imageService = ImageUploadService()
        let snapshot = try await db.collection("recipes")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for document in snapshot.documents {
            try? await imageService.deleteImage(recipeId: document.documentID)
            try await document.reference.delete()
        }
        // Clean up follows and saves
        let followingSnapshot = try await db.collection("follows")
            .whereField("followerId", isEqualTo: uid)
            .getDocuments()
        for doc in followingSnapshot.documents { try await doc.reference.delete() }

        let followerSnapshot = try await db.collection("follows")
            .whereField("followingId", isEqualTo: uid)
            .getDocuments()
        for doc in followerSnapshot.documents { try await doc.reference.delete() }

        let savedSnapshot = try await db.collection("saved")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in savedSnapshot.documents { try await doc.reference.delete() }

        // Their comments, likes, and inbound notifications
        let commentsSnapshot = try await db.collection("comments")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in commentsSnapshot.documents { try? await doc.reference.delete() }

        let likesSnapshot = try await db.collection("likes")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        for doc in likesSnapshot.documents { try? await doc.reference.delete() }

        let notificationsSnapshot = try await db.collection("notifications")
            .whereField("recipientId", isEqualTo: uid)
            .getDocuments()
        for doc in notificationsSnapshot.documents { try? await doc.reference.delete() }

        try await db.collection("users").document(uid).delete()
    }

    // MARK: - Follow

    func followUser(followerId: String, followingId: String) async throws {
        let docId = "\(followerId)_\(followingId)"
        try await db.collection("follows").document(docId).setData([
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func unfollowUser(followerId: String, followingId: String) async throws {
        let docId = "\(followerId)_\(followingId)"
        try await db.collection("follows").document(docId).delete()
    }

    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        let docId = "\(followerId)_\(followingId)"
        let doc = try await db.collection("follows").document(docId).getDocument()
        return doc.exists
    }

    func fetchFollowerCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.count
    }

    func fetchFollowingCount(userId: String) async throws -> Int {
        let snapshot = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        return snapshot.documents.count
    }

    func fetchFollowers(userId: String) async throws -> [NommieUser] {
        let snap = try await db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .getDocuments()
        let ids = snap.documents.compactMap { $0.data()["followerId"] as? String }
        let users = try await fetchUsers(ids: ids)

        // Self-heal: follow docs pointing at deleted accounts make counts
        // disagree with lists. Remove them as we find them.
        let foundIds = Set(users.map { $0.id })
        for missingId in Set(ids).subtracting(foundIds) {
            try? await db.collection("follows").document("\(missingId)_\(userId)").delete()
        }
        return users
    }

    func fetchFollowing(userId: String) async throws -> [NommieUser] {
        let snap = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        let ids = snap.documents.compactMap { $0.data()["followingId"] as? String }
        let users = try await fetchUsers(ids: ids)

        let foundIds = Set(users.map { $0.id })
        for missingId in Set(ids).subtracting(foundIds) {
            try? await db.collection("follows").document("\(userId)_\(missingId)").delete()
        }
        return users
    }

    /// Batched profile lookup keyed by user id — used to hydrate avatars for
    /// feed authors, follower lists, and comment threads.
    func fetchUserMap(ids: [String]) async throws -> [String: NommieUser] {
        let users = try await fetchUsers(ids: Array(Set(ids)))
        return Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    private func fetchUsers(ids: [String]) async throws -> [NommieUser] {
        guard !ids.isEmpty else { return [] }
        var users: [NommieUser] = []
        let chunks = stride(from: 0, to: ids.count, by: 30).map {
            Array(ids[$0..<min($0 + 30, ids.count)])
        }
        for chunk in chunks {
            let snap = try await db.collection("users").whereField("uid", in: chunk).getDocuments()
            users += snap.documents.compactMap { NommieUser(from: $0.data()) }
        }
        return users
    }

    // MARK: - Report & Block (App Store UGC requirements)

    func reportRecipe(recipeId: String, recipeOwnerId: String, reporterId: String, reason: String) async throws {
        try await db.collection("reports").addDocument(data: [
            "recipeId": recipeId,
            "recipeOwnerId": recipeOwnerId,
            "reporterId": reporterId,
            "reason": reason,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func blockUser(blockerId: String, blockedId: String) async throws {
        let docId = "\(blockerId)_\(blockedId)"
        try await db.collection("blocks").document(docId).setData([
            "blockerId": blockerId,
            "blockedId": blockedId,
            "createdAt": Timestamp(date: Date())
        ])
        // Sever the follow relationship in both directions
        try? await db.collection("follows").document("\(blockerId)_\(blockedId)").delete()
        try? await db.collection("follows").document("\(blockedId)_\(blockerId)").delete()
    }

    func unblockUser(blockerId: String, blockedId: String) async throws {
        let docId = "\(blockerId)_\(blockedId)"
        try await db.collection("blocks").document(docId).delete()
    }

    func isBlocked(blockerId: String, blockedId: String) async throws -> Bool {
        let docId = "\(blockerId)_\(blockedId)"
        let doc = try await db.collection("blocks").document(docId).getDocument()
        return doc.exists
    }

    func fetchBlockedUserIds(blockerId: String) async throws -> Set<String> {
        let snapshot = try await db.collection("blocks")
            .whereField("blockerId", isEqualTo: blockerId)
            .getDocuments()
        return Set(snapshot.documents.compactMap { $0.data()["blockedId"] as? String })
    }

    // MARK: - Likes

    func likeRecipe(userId: String, username: String, recipeId: String) async throws {
        let docId = "\(userId)_\(recipeId)"
        try await db.collection("likes").document(docId).setData([
            "userId": userId,
            "username": username,
            "recipeId": recipeId,
            "likedAt": Timestamp(date: Date())
        ])
    }

    func unlikeRecipe(userId: String, recipeId: String) async throws {
        let docId = "\(userId)_\(recipeId)"
        try await db.collection("likes").document(docId).delete()
    }

    func isLiked(userId: String, recipeId: String) async throws -> Bool {
        let doc = try await db.collection("likes").document("\(userId)_\(recipeId)").getDocument()
        return doc.exists
    }

    /// Which of these recipes has the user liked? Batched by deterministic doc ID.
    func fetchLikedRecipeIds(userId: String, recipeIds: [String]) async throws -> Set<String> {
        guard !recipeIds.isEmpty else { return [] }
        let docIds = recipeIds.map { "\(userId)_\($0)" }
        var liked: Set<String> = []
        let chunks = stride(from: 0, to: docIds.count, by: 30).map {
            Array(docIds[$0..<min($0 + 30, docIds.count)])
        }
        for chunk in chunks {
            let snap = try await db.collection("likes")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            for doc in snap.documents {
                if let recipeId = doc.data()["recipeId"] as? String {
                    liked.insert(recipeId)
                }
            }
        }
        return liked
    }

    // MARK: - Save / Bookmark

    func saveRecipe(userId: String, recipeId: String) async throws {
        let docId = "\(userId)_\(recipeId)"
        try await db.collection("saved").document(docId).setData([
            "userId": userId,
            "recipeId": recipeId,
            "savedAt": Timestamp(date: Date())
        ])
    }

    func unsaveRecipe(userId: String, recipeId: String) async throws {
        let docId = "\(userId)_\(recipeId)"
        try await db.collection("saved").document(docId).delete()
    }

    func isSaved(userId: String, recipeId: String) async throws -> Bool {
        let docId = "\(userId)_\(recipeId)"
        let doc = try await db.collection("saved").document(docId).getDocument()
        return doc.exists
    }

    func fetchRecipe(id: String) async throws -> Recipe? {
        let doc = try await db.collection("recipes").document(id).getDocument()
        guard let data = doc.data() else { return nil }
        return Recipe(from: data)
    }

    func fetchMostRecentRecipe(userId: String) async throws -> Recipe? {
        let snap = try await db.collection("recipes")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        return snap.documents.first.flatMap { Recipe(from: $0.data()) }
    }

    // MARK: - Recipe search

    // The @username whose account new users auto-follow, and whose handle
    // seeds an empty search. Set to your own username; empty disables both.
    static let founderUsername = "ubinnoms"

    /// Searches all recipes by denormalized searchTerms (tags, dish words,
    /// ingredients, macro labels). Newest first, blocked authors removed.
    func searchRecipes(term: String, blockedIds: Set<String> = []) async throws -> [Recipe] {
        let q = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        let snap = try await db.collection("recipes")
            .whereField("searchTerms", arrayContains: q)
            .limit(to: 40)
            .getDocuments()

        return snap.documents
            .compactMap { Recipe(from: $0.data()) }
            .filter { !blockedIds.contains($0.userId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// New accounts follow the founder so their feed isn't empty. No-op if
    /// the founder username is unset or can't be resolved.
    func autoFollowFounder(newUserId: String) async {
        let handle = Self.founderUsername
        guard !handle.isEmpty else { return }
        guard let founder = try? await fetchUserProfileByUsername(handle),
              founder.id != newUserId else { return }
        try? await followUser(followerId: newUserId, followingId: founder.id)
    }

    func fetchSavedRecipes(userId: String) async throws -> [Recipe] {
        // Skip order(by:) to avoid composite-index requirement; sort in memory.
        let savedSnapshot = try await db.collection("saved")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let savedDocs = savedSnapshot.documents
        let recipeIds = savedDocs.compactMap { $0.data()["recipeId"] as? String }
        guard !recipeIds.isEmpty else { return [] }

        // Build savedAt order map for in-memory sorting
        var savedAtMap: [String: Date] = [:]
        for doc in savedDocs {
            if let id = doc.data()["recipeId"] as? String,
               let ts = doc.data()["savedAt"] as? Timestamp {
                savedAtMap[id] = ts.dateValue()
            }
        }

        var recipes: [Recipe] = []
        let chunks = stride(from: 0, to: recipeIds.count, by: 30).map {
            Array(recipeIds[$0..<min($0 + 30, recipeIds.count)])
        }
        for chunk in chunks {
            let snapshot = try await db.collection("recipes")
                .whereField("id", in: chunk)
                .getDocuments()
            recipes += snapshot.documents.compactMap { Recipe(from: $0.data()) }
        }

        // Sort by savedAt descending
        recipes.sort {
            (savedAtMap[$0.id] ?? .distantPast) > (savedAtMap[$1.id] ?? .distantPast)
        }
        return recipes
    }
}
