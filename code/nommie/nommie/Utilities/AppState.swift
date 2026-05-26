import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserID: String? = nil
    @Published var isLoading: Bool = false
}
