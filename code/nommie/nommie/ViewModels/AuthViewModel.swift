import SwiftUI
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

enum AuthFlow {
    case splash
    case welcome
    case signUp
    case logIn
    case usernameSetup
    case home
}

class AuthViewModel: ObservableObject {
    @Published var currentFlow: AuthFlow = .splash
    @Published var newUserID: String = ""
    @Published var newUserEmail: String = ""
    @Published var newUsername: String = ""
    @Published var errorMessage: String = ""
    @Published var infoMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var currentNommieUser: NommieUser? = nil
    @Published var pendingDeepLinkRecipeId: String? = nil
    private(set) var currentNonce: String? = nil

    var isAppleUser: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == "apple.com" } ?? false
    }

    private let authService = AuthService()
    private let userService = UserService()

    init() {
        checkAuthState()
    }

    func checkAuthState() {
        if let user = Auth.auth().currentUser {
            newUserID = user.uid
            newUserEmail = user.email ?? ""
            Task {
                await fetchCurrentUser(uid: user.uid)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.currentFlow = .welcome
            }
        }
    }

    func fetchCurrentUser(uid: String) async {
        do {
            if let data = try await userService.fetchUserProfile(uid: uid),
               let user = NommieUser(from: data) {
                await MainActor.run {
                    self.currentNommieUser = user
                    self.currentFlow = .home
                }
                NotificationService.shared.registerIfPermitted()
            } else {
                await MainActor.run {
                    self.currentFlow = .usernameSetup
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't load your profile. Please check your connection and try again."
                self.currentFlow = .welcome
            }
        }
    }

    func signUp(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            infoMessage = ""
        }
        do {
            try await authService.signUp(email: email, password: password)
            if let user = Auth.auth().currentUser {
                await MainActor.run {
                    self.newUserID = user.uid
                    self.newUserEmail = email
                    self.isLoading = false
                    self.currentFlow = .usernameSetup
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't create your account. Please check your details and try again."
                self.isLoading = false
            }
        }
    }

    func signIn(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            infoMessage = ""
        }
        do {
            try await authService.signIn(email: email, password: password)
            if let user = Auth.auth().currentUser {
                await MainActor.run {
                    self.newUserID = user.uid
                    self.newUserEmail = user.email ?? email
                }
                await fetchCurrentUser(uid: user.uid)
            }
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't log in. Please check your email and password."
                self.isLoading = false
            }
        }
    }

    func sendPasswordReset(email: String) async {
        guard !email.isEmpty else {
            await MainActor.run {
                self.infoMessage = ""
                self.errorMessage = "Enter your email above first, then tap Forgot password."
            }
            return
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            await MainActor.run {
                self.errorMessage = ""
                self.infoMessage = "Password reset link sent. Check your email."
            }
        } catch {
            await MainActor.run {
                self.infoMessage = ""
                self.errorMessage = "Couldn't send a reset link. Check your email and try again."
            }
        }
    }

    func saveUsername(username: String) {
        newUsername = username
        Task {
            await MainActor.run { isLoading = true }
            do {
                try await userService.createUserProfile(
                    uid: newUserID,
                    username: username,
                    email: newUserEmail
                )
                if let data = try await userService.fetchUserProfile(uid: newUserID),
                   let user = NommieUser(from: data) {
                    await MainActor.run {
                        self.currentNommieUser = user
                        self.isLoading = false
                        self.currentFlow = .home
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Something went wrong saving your profile. Please try again."
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Deep Links

    func handleDeepLink(_ url: URL) {
        guard url.host == "getnommie.app" else { return }
        let parts = url.pathComponents
        guard parts.count == 3, parts[1].hasPrefix("@") else { return }
        pendingDeepLinkRecipeId = parts[2]
    }

    // MARK: - Sign in with Apple

    func prepareAppleDeleteAccount() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func deleteAccountWithApple(authorization: ASAuthorization) async -> Bool {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            await MainActor.run { self.errorMessage = "Apple re-authentication failed. Please try again." }
            return false
        }
        await MainActor.run { self.isLoading = true; self.errorMessage = "" }
        let firebaseCredential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: credential.fullName)
        do {
            guard let user = Auth.auth().currentUser else { return false }
            try await user.reauthenticate(with: firebaseCredential)
            try await userService.deleteAllUserData(uid: user.uid)
            try await user.delete()
            await MainActor.run {
                self.currentNommieUser = nil
                self.isLoading = false
                self.currentFlow = .welcome
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't delete your account. Please try again."
                self.isLoading = false
            }
            return false
        }
    }

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func signInWithApple(authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            await MainActor.run { self.errorMessage = "Apple sign in failed. Please try again." }
            return
        }
        await MainActor.run { self.isLoading = true; self.errorMessage = "" }
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            await fetchCurrentUser(uid: result.user.uid)
            await MainActor.run { self.isLoading = false }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't sign in with Apple. Please try again."
                self.isLoading = false
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    func signOut() {
        do {
            NotificationService.shared.clearToken()
            try authService.signOut()
            currentNommieUser = nil
            currentFlow = .welcome
        } catch {
            errorMessage = "Couldn't sign out. Please try again."
        }
    }

    // Apple Guideline 5.1.1(v): account-based apps must let users delete their account in-app.
    func deleteAccount(password: String) async -> Bool {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }
        guard let user = Auth.auth().currentUser, let email = user.email else {
            await MainActor.run {
                self.errorMessage = "You're not signed in. Please log in again."
                self.isLoading = false
            }
            return false
        }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            try await userService.deleteAllUserData(uid: user.uid)
            try await user.delete()
            await MainActor.run {
                self.currentNommieUser = nil
                self.isLoading = false
                self.currentFlow = .welcome
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't delete your account. Please check your password and try again."
                self.isLoading = false
            }
            return false
        }
    }
}
