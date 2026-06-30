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
        return try await fetchUsers(ids: ids)
    }

    func fetchFollowing(userId: String) async throws -> [NommieUser] {
        let snap = try await db.collection("follows")
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        let ids = snap.documents.compactMap { $0.data()["followingId"] as? String }
        return try await fetchUsers(ids: ids)
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
