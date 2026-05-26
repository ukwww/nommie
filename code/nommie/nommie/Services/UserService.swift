import Foundation
import FirebaseFirestore
import Combine

class UserService {
    private let db = Firestore.firestore()
    
    func createUserProfile(uid: String, username: String, email: String, theme: String) async throws {
        let data: [String: Any] = [
            "uid": uid,
            "username": username,
            "email": email,
            "selectedTheme": theme,
            "createdAt": Timestamp(date: Date())
        ]
        try await db.collection("users").document(uid).setData(data)
    }
    
    func fetchUserProfile(uid: String) async throws -> [String: Any]? {
        let document = try await db.collection("users").document(uid).getDocument()
        return document.data()
    }
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        return snapshot.documents.isEmpty
    }
}
