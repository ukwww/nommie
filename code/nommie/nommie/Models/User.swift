import Foundation
import FirebaseFirestore

struct NommieUser: Identifiable, Codable {
    var id: String
    var username: String
    var email: String
    var createdAt: Date

    init(id: String, username: String, email: String, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.createdAt = createdAt
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
    }
}
