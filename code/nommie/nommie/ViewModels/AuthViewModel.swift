import SwiftUI
import Combine
import FirebaseAuth

enum AuthFlow {
    case splash
    case welcome
    case signUp
    case logIn
    case usernameSetup
    case themeSelection
    case home
}

class AuthViewModel: ObservableObject {
    @Published var currentFlow: AuthFlow = .splash
    @Published var newUserID: String = ""
    @Published var newUserEmail: String = ""
    @Published var newUsername: String = ""
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var currentNommieUser: NommieUser? = nil

    private let authService = AuthService()
    private let userService = UserService()

    init() {
        checkAuthState()
    }

    func checkAuthState() {
        if let user = Auth.auth().currentUser {
            newUserID = user.uid
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
            if let data = try await userService.fetchUserProfile(uid: uid) {
                if let user = NommieUser(from: data) {
                    await MainActor.run {
                        self.currentNommieUser = user
                        self.currentFlow = .home
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.currentFlow = .welcome
            }
        }
    }

    func signUp(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
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
        }
        do {
            try await authService.signIn(email: email, password: password)
            if let user = Auth.auth().currentUser {
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

    func saveUsername(username: String) {
        newUsername = username
        currentFlow = .themeSelection
    }

    func saveThemeAndFinish(username: String, theme: String) async {
        await MainActor.run { isLoading = true }
        do {
            try await userService.createUserProfile(
                uid: newUserID,
                username: username,
                email: newUserEmail,
                theme: theme
            )
            if let data = try await userService.fetchUserProfile(uid: newUserID) {
                if let user = NommieUser(from: data) {
                    await MainActor.run {
                        self.currentNommieUser = user
                        self.isLoading = false
                        self.currentFlow = .home
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Something went wrong saving your profile. Please try again."
                self.isLoading = false
            }
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            currentNommieUser = nil
            currentFlow = .welcome
        } catch {
            errorMessage = "Couldn't sign out. Please try again."
        }
    }
}
