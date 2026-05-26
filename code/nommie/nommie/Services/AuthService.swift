import Foundation
import FirebaseAuth
import Combine

class AuthService: ObservableObject {
    @Published var currentUser: FirebaseAuth.User? = nil
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { _, user in
            self.currentUser = user
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        await MainActor.run {
            self.currentUser = result.user
        }
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await MainActor.run {
            self.currentUser = result.user
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        self.currentUser = nil
    }
}
