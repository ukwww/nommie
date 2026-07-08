import Foundation
import FirebaseFirestore

struct NommieUser: Identifiable, Codable {
    var id: String
    var username: String
    var email: String
    var createdAt: Date
    var exportCount: Int
    var photoURL: String
    var bio: String
    var usernameChangedAt: Date?

    init(id: String, username: String, email: String, createdAt: Date = Date(), exportCount: Int = 0, photoURL: String = "", bio: String = "", usernameChangedAt: Date? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.createdAt = createdAt
        self.exportCount = exportCount
        self.photoURL = photoURL
        self.bio = bio
        self.usernameChangedAt = usernameChangedAt
    }

    init?(from dictionary: [String: Any]) {
        guard
            let id = dictionary["uid"] as? String,
            let username = dictionary["username"] as? String,
            let email = dictionary["email"] as? String,
            let timestamp = dictionary["createdAt"] as? Timestamp
        else { return nil }

        self.id = id
        self.username = username
        self.email = email
        self.createdAt = timestamp.dateValue()
        self.exportCount = dictionary["exportCount"] as? Int ?? 0
        self.photoURL = dictionary["photoURL"] as? String ?? ""
        self.bio = dictionary["bio"] as? String ?? ""
        self.usernameChangedAt = (dictionary["usernameChangedAt"] as? Timestamp)?.dateValue()
    }
}
